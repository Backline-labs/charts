{{- define "common.validateRequired" -}}
{{- if not (or .Values.accessKey ((.Values.externalSecrets).accessKey).enabled) }}
  {{- fail "accessKey is required. Set it in values.yaml, with --set accessKey=<value>, or source it from a secret manager with externalSecrets.accessKey.enabled=true" }}
{{- end }}
{{- if not .Values.environment }}
  {{- fail "environment is required. Please set it in values.yaml or with --set environment=<value>" }}
{{- end }}
{{- range (((.Values.seaweedfs).allInOne).s3).createBuckets }}
{{- if .ttl }}
  {{- include "backline.validateTtl" .ttl }}
{{- end }}
{{- end }}
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
{{- end -}}

{{- define "logging.dir" -}}
{{ printf "/var/log/backline" }}
{{- end -}}

{{- define "logging.roleArn" -}}
{{- if eq .Values.environment "production" -}}
arn:aws:iam::314146328431:role/OnPremOtelShipRole
{{- else -}}
arn:aws:iam::580550010989:role/OnPremOtelShipRole
{{- end -}}
{{- end -}}

{{- define "image.registry" -}}
{{- if eq .Values.environment "staging" -}}
580550010989.dkr.ecr.us-west-1.amazonaws.com
{{- else -}}
314146328431.dkr.ecr.us-east-1.amazonaws.com
{{- end -}}
{{- end -}}

{{- define "image.namePrefix" -}}
{{- if ne .Values.environment "staging" -}}prod-{{- end -}}
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
{{- if eq .Values.environment "staging" -}}
us-west-1
{{- else -}}
us-east-1
{{- end -}}
{{- end -}}

{{- define "baseUrl" -}}
{{- if eq .Values.environment "production" -}}
https://app.backline.ai
{{- else -}}
https://staging-app.backline.ai
{{- end -}}
{{- end -}}

{{- define "secretname.langfuse" -}}
{{ printf "langfuse-config" | quote }}
{{- end -}}

{{- define "janitor.totalSteps" -}}
{{- $steps := 5 -}}
{{- if ((.Values.gitproxy).enabled) }}{{- $steps = add $steps 1 -}}{{- end -}}
{{- $steps -}}
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

