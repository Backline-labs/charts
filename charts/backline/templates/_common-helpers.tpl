{{- define "common.validateRequired" -}}
{{- if not (or .Values.accessKey ((.Values.externalSecrets).accessKey).enabled) }}
  {{- fail "accessKey is required. Set it in values.yaml, with --set accessKey=<value>, or source it from a secret manager with externalSecrets.accessKey.enabled=true" }}
{{- end }}
{{- if .Values.seaweedfs.enabled }}
{{- range include "backline.buckets" . | fromJson }}
{{- if .ttl }}
  {{- include "backline.validateTtl" .ttl }}
{{- end }}
{{- end }}
{{- end }}
{{- end -}}

{{/*
Buckets from files/buckets.json as JSON. objectStorage.operationalRetention overrides the
operational ttl; before 1.6.0 it was set in seaweedfs.allInOne.s3.createBuckets, still honoured.
*/}}
{{- define "backline.buckets" -}}
{{- $buckets := .Files.Get "files/buckets.json" | fromJson -}}
{{- $ttl := (.Values.objectStorage).operationalRetention -}}
{{- if not $ttl -}}
{{- range (((.Values.seaweedfs).allInOne).s3).createBuckets -}}
{{- if and (eq .name "operational") .ttl -}}{{- $ttl = .ttl -}}{{- end -}}
{{- end -}}
{{- end -}}
{{- if $ttl -}}{{- $_ := set $buckets.operational "ttl" (toString $ttl) -}}{{- end -}}
{{- toJson $buckets -}}
{{- end -}}

{{/* Internal: Backline's own installs pass environment=staging; anything else is production. */}}
{{- define "backline.isStaging" -}}
{{- if eq (toString .Values.environment) "staging" -}}true{{- end -}}
{{- end -}}

{{/* Non-empty when a custom CA is supplied, inline or through an ExternalSecret. */}}
{{- define "backline.customCa.enabled" -}}
{{- if or .Values.customCaCert ((.Values.externalSecrets).customCaCert).enabled -}}true{{- end -}}
{{- end -}}

{{- define "secretname.dockerconfig" -}}
{{ printf "dockerconfig" | quote }}
{{- end -}}

{{- define "secretname.sessionjwt" -}}
{{ printf "session-jwt" | quote }}
{{- end -}}

{{- define "common.podSecurityContext" -}}
runAsNonRoot: true
runAsUser: 1020
runAsGroup: 1010
fsGroup: 1010
fsGroupChangePolicy: OnRootMismatch
seccompProfile:
  type: RuntimeDefault
{{- end -}}

{{- define "logging.dir" -}}
{{ printf "/var/log/backline" }}
{{- end -}}

{{- define "logging.roleArn" -}}
{{- if include "backline.isStaging" . -}}
arn:aws:iam::580550010989:role/OnPremOtelShipRole
{{- else -}}
arn:aws:iam::314146328431:role/OnPremOtelShipRole
{{- end -}}
{{- end -}}

{{- define "image.registry" -}}
{{- if include "backline.isStaging" . -}}
580550010989.dkr.ecr.us-west-1.amazonaws.com
{{- else -}}
314146328431.dkr.ecr.us-east-1.amazonaws.com
{{- end -}}
{{- end -}}

{{- define "image.namePrefix" -}}
{{- if not (include "backline.isStaging" .) -}}prod-{{- end -}}
{{- end -}}

{{/*
Tag for a janitor-managed Deployment (args: root, deployment, tag). An explicit tag wins.
Otherwise reuse the tag currently deployed so helm upgrade keeps the janitor's choice; the
bootstrap placeholder (older than any published build) applies only when no Deployment
exists yet or there is no cluster to look at (helm template, client dry-run).
*/}}
{{- define "backline.image.tag" -}}
{{- $placeholder := "0000001-0000000001" -}}
{{- $tag := toString (default "" .tag) -}}
{{- if or (not $tag) (eq $tag $placeholder) -}}
{{- $tag = $placeholder -}}
{{- $ns := default .root.Release.Namespace .root.Values.namespaceOverride | trunc 63 | trimSuffix "-" -}}
{{- with lookup "apps/v1" "Deployment" $ns .deployment -}}
{{- range .spec.template.spec.containers -}}
{{- if eq .name $.deployment -}}
{{- $tag = splitList ":" .image | last -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- $tag -}}
{{- end -}}

{{- define "worker.image.name" -}}{{ include "image.namePrefix" . }}runner{{- end -}}

{{- define "gitproxy.image.name" -}}{{ include "image.namePrefix" . }}gitproxy{{- end -}}

{{- define "region" -}}
{{- if include "backline.isStaging" . -}}
us-west-1
{{- else -}}
us-east-1
{{- end -}}
{{- end -}}

{{- define "baseUrl" -}}
{{- if include "backline.isStaging" . -}}
https://staging-app.backline.ai
{{- else -}}
https://app.backline.ai
{{- end -}}
{{- end -}}

{{- define "secretname.langfuse" -}}
{{ printf "langfuse-config" | quote }}
{{- end -}}

{{- define "janitor.image" -}}
{{ .Values.janitor.image.registry }}/dtzar/helm-kubectl:3.16.1
{{- end -}}

{{- define "adot.collectorImage" -}}
public.ecr.aws/aws-observability/aws-otel-collector:v0.45.1
{{- end -}}

{{- define "common.containerSecurityContext" -}}
allowPrivilegeEscalation: false
readOnlyRootFilesystem: {{ if hasKey . "readOnlyRootFilesystem" }}{{ .readOnlyRootFilesystem }}{{ else }}false{{ end }}
capabilities:
  drop:
    - ALL
{{- end -}}

{{/*
Reject a bucket ttl that weed's own fs.configure would refuse, which it reports without
failing the hook that applies it.
*/}}
{{- define "backline.validateTtl" -}}
{{- $ttl := toString . -}}
{{- if not (regexMatch "^(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]?)[mhdwMy]$" $ttl) -}}
{{- fail (printf "invalid object storage ttl %q: expected a count of 1-255 followed by m, h, d, w, M or y; counts above 255 need a coarser unit (1y, not 365d)" $ttl) -}}
{{- end -}}
{{- end -}}

{{/*
Outbound proxy environment variables for components that egress through a
corporate proxy. Emitted in both upper- and lower-case so Go- and shell-based
components honour them, and only for the fields that are set.
*/}}
{{- define "backline.proxyEnv" -}}
{{- with .Values.proxy }}
{{- if .httpProxy }}
- name: HTTP_PROXY
  value: {{ .httpProxy | quote }}
- name: http_proxy
  value: {{ .httpProxy | quote }}
{{- end }}
{{- if .httpsProxy }}
- name: HTTPS_PROXY
  value: {{ .httpsProxy | quote }}
- name: https_proxy
  value: {{ .httpsProxy | quote }}
{{- end }}
{{- if .noProxy }}
- name: NO_PROXY
  value: {{ .noProxy | quote }}
- name: no_proxy
  value: {{ .noProxy | quote }}
{{- end }}
{{- end }}
{{- end -}}

