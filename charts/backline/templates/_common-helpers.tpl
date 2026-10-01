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
Buckets from files/buckets.yaml, rendered as JSON. objectStorage.operationalRetention overrides the
operational ttl; before 1.6.0 it was set in seaweedfs.allInOne.s3.createBuckets, still honoured.
*/}}
{{- define "backline.buckets" -}}
{{- $buckets := .Files.Get "files/buckets.yaml" | fromYaml -}}
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

{{/*
Deployments the janitor restarts after writing LOG_STREAM_NAME, the tenant ID it reads from the
access key's JWT. It is not a setting: empty until the janitor's first run, then fixed per access key.
*/}}
{{- define "janitor.restartDeployments" -}}
worker{{ if .Values.gitproxy.enabled }} gitproxy{{ end }}
{{- end -}}

{{/* janitor.image.name / .tag are deprecated but still honoured so mirrored installs keep pulling. */}}
{{- define "janitor.image" -}}
{{- $image := .Values.janitor.image -}}
{{ $image.registry }}/{{ $image.name | default "dtzar/helm-kubectl" }}:{{ $image.tag | default "3.16.1" }}
{{- end -}}

{{/*
Collector image (args: root context, optional component). The deprecated *.otel.collector.image
overrides are still honoured; gitproxy falls back to the worker's, which also covers a mirror.
*/}}
{{- define "adot.collectorImage" -}}
{{- $image := "public.ecr.aws/aws-observability/aws-otel-collector:v0.45.1" -}}
{{- $components := list "worker" -}}
{{- if eq (toString .component) "gitproxy" -}}{{- $components = list "worker" "gitproxy" -}}{{- end -}}
{{- range $components -}}
{{- with (((index $.Values .) | default dict).otel | default dict).collector -}}
{{- with .image -}}{{- $image = . -}}{{- end -}}
{{- end -}}
{{- end -}}
{{- $image -}}
{{- end -}}

{{/*
Notices for values removed in 1.6.0, as a JSON list for NOTES.txt. A value is reported only when
it differs from its old default, so --reuse-values (which replays old defaults) stays quiet.
*/}}
{{- define "backline.deprecations" -}}
{{- $msgs := list -}}
{{- $v := .Values -}}
{{- $env := toString (default "" $v.environment) -}}
{{- if and $env (not (has $env (list "production" "staging"))) -}}
{{- $msgs = append $msgs (printf "environment (%q) is no longer read: the chart always connects to Backline production. Remove it." $env) -}}
{{- end -}}
{{- $oldProbes := dict
  "livenessProbe" (dict "httpGet" (dict "path" "/health" "port" 8080) "initialDelaySeconds" 10 "periodSeconds" 5)
  "readinessProbe" (dict "httpGet" (dict "path" "/readiness" "port" 8080) "initialDelaySeconds" 5 "periodSeconds" 3) -}}
{{- $collector := "public.ecr.aws/aws-observability/aws-otel-collector:v0.45.1" -}}
{{- range $c := list "worker" "gitproxy" -}}
{{- $cfg := index $v $c | default dict -}}
{{- with ($cfg.service | default dict).httpPort -}}
{{- if ne (int .) 8080 -}}
{{- $msgs = append $msgs (printf "%s.service.httpPort (%v) is no longer read: the service always listens on 8080. Remove it." $c .) -}}
{{- end -}}
{{- end -}}
{{- range $p, $old := $oldProbes -}}
{{- with index $cfg $p -}}
{{- if ne (toJson .) (toJson $old) -}}
{{- $msgs = append $msgs (printf "%s.%s is no longer read: the chart sets the probes. Remove it." $c $p) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- $otel := $cfg.otel | default dict -}}
{{- if and (hasKey $otel "enabled") (not $otel.enabled) -}}
{{- $msgs = append $msgs (printf "%s.otel.enabled is no longer read: telemetry to Backline is always on. Remove it." $c) -}}
{{- end -}}
{{- with ($otel.collector | default dict).image -}}
{{- if ne . $collector -}}
{{- $msgs = append $msgs (printf "%s.otel.collector.image is deprecated. Its value (%s) is still used, but a future release will stop reading it." $c .) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- $gp := $v.gitproxy | default dict -}}
{{- if ($gp.adapter | default dict).skipCertVerification -}}
{{- $msgs = append $msgs "gitproxy.adapter.skipCertVerification is no longer read: TLS to Backline is always verified. Trust an inspecting proxy through customCaCert instead." -}}
{{- end -}}
{{- $tuning := list
  (list "gitproxy.adapter.maxRetries" ($gp.adapter | default dict).maxRetries "3")
  (list "gitproxy.adapter.retryDelay" ($gp.adapter | default dict).retryDelay "1s")
  (list "gitproxy.temporal.maxConcurrentActivities" ($gp.temporal | default dict).maxConcurrentActivities "20") -}}
{{- range $tuning -}}
{{- $value := index . 1 -}}
{{- if and (not (kindIs "invalid" $value)) (ne (toString $value) (index . 2)) -}}
{{- $msgs = append $msgs (printf "%s (%v) is no longer read: GitProxy's built-in default (%s) applies. Remove it." (index . 0) $value (index . 2)) -}}
{{- end -}}
{{- end -}}
{{- $janitor := $v.janitor.image -}}
{{- if and $janitor.name (ne $janitor.name "dtzar/helm-kubectl") -}}
{{- $msgs = append $msgs (printf "janitor.image.name is deprecated. Its value (%s) is still used, but a future release will stop reading it." $janitor.name) -}}
{{- end -}}
{{- if and $janitor.tag (ne (toString $janitor.tag) "3.16.1") -}}
{{- $msgs = append $msgs (printf "janitor.image.tag is deprecated. Its value (%v) is still used, but a future release will stop reading it." $janitor.tag) -}}
{{- end -}}
{{- $legacy := (((($v.seaweedfs | default dict).allInOne | default dict).s3 | default dict).createBuckets) -}}
{{- $oldBuckets := list (dict "name" "operational" "ttl" "7d") (dict "name" "static-assets") -}}
{{- if and $legacy (ne (toJson $legacy) (toJson $oldBuckets)) -}}
{{- $legacyTtl := "" -}}
{{- range $legacy -}}{{- if and (eq .name "operational") .ttl -}}{{- $legacyTtl = toString .ttl -}}{{- end -}}{{- end -}}
{{- if and $legacyTtl (not ($v.objectStorage).operationalRetention) -}}
{{- $msgs = append $msgs (printf "seaweedfs.allInOne.s3.createBuckets is deprecated. Its operational ttl (%s) is applied as objectStorage.operationalRetention; set that value and remove the list." $legacyTtl) -}}
{{- else -}}
{{- $msgs = append $msgs "seaweedfs.allInOne.s3.createBuckets is deprecated: the chart sets the buckets, and objectStorage.operationalRetention sets the operational window. Remove the list." -}}
{{- end -}}
{{- end -}}
{{- toJson $msgs -}}
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

