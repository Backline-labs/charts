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

{{- define "adot.volumes" -}}
- name: adot-config
  configMap:
    name: adot-config
- name: {{ include "secretname.sessionjwt" . }}
  secret:
    secretName: {{ include "secretname.sessionjwt" . }}
- name: shared-logs
  emptyDir: {}
{{- end -}}

{{- define "adot.logVolumeMount" -}}
- name: shared-logs
  mountPath: "/var/log/backline"
  readOnly: {{ if hasKey . "readOnly" }}{{ .readOnly }}{{ else }}true{{ end }}
{{- end -}}

{{- define "adot.sidecar" -}}
- name: adot-collector
  image: {{ .Values.worker.otel.collector.image }}
  args: ["--config=/etc/otel/config.yaml"]
  ports:
    - containerPort: 4317
      name: otlp
      protocol: TCP
  env:
    - name: ACCESS_KEY
      valueFrom:
        secretKeyRef:
          name: accesskey
          key: ACCESS_KEY
    - name: POD_IP
      valueFrom:
        fieldRef:
          fieldPath: status.podIP
    - name: AWS_WEB_IDENTITY_TOKEN_FILE
      value: "/var/run/descope/session.jwt"
    - name: AWS_ROLE_ARN
      value: {{ include "logging.roleArn" . | quote }}
    - name: AWS_REGION
      value: {{ include "region" . | quote }}
    - name: LOG_STREAM_NAME
      valueFrom:
        configMapKeyRef:
          name: worker
          key: LOG_STREAM_NAME
  securityContext:
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    capabilities:
      drop:
        - ALL
  volumeMounts:
    {{- include "adot.logVolumeMount" . | nindent 4 }}
    - name: adot-config
      mountPath: /etc/otel/
    - name: {{ include "secretname.sessionjwt" . }}
      mountPath: "/var/run/descope/session.jwt"
      subPath: token
      readOnly: true
{{- end -}}

{{- define "common.podSecurityContext" -}}
runAsNonRoot: false
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