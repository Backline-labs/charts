{{- define "common.validateRequired" -}}
{{- if not .Values.accessKey }}
  {{- fail "accessKey is required. Please set it in values.yaml or with --set accessKey=<value>" }}
{{- end }}
{{- if not .Values.environment }}
  {{- fail "environment is required. Please set it in values.yaml or with --set environment=<value>" }}
{{- end }}
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

{{- define "worker.image.registry" -}}
{{- if eq .Values.environment "staging" -}}
580550010989.dkr.ecr.us-west-1.amazonaws.com
{{- else -}}
314146328431.dkr.ecr.us-east-1.amazonaws.com
{{- end -}}
{{- end -}}

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

{{- define "common.containerSecurityContext" -}}
allowPrivilegeEscalation: false
readOnlyRootFilesystem: {{ if hasKey . "readOnlyRootFilesystem" }}{{ .readOnlyRootFilesystem }}{{ else }}false{{ end }}
capabilities:
  drop:
    - ALL
{{- end -}}