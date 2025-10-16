{{- define "common.validateRequired" -}}
{{- if not .Values.baseUrl }}
  {{- fail "baseUrl is required. Please set it in values.yaml or with --set baseUrl=<value>" }}
{{- end }}
{{- if not .Values.accessKey }}
  {{- fail "accessKey is required. Please set it in values.yaml or with --set accessKey=<value>" }}
{{- end }}
{{- if not .Values.logging.region }}
  {{- fail "logging.region is required. Please set it in values.yaml or with --set logging.region=<value>" }}
{{- end }}
{{- if not .Values.logging.environment }}
  {{- fail "logging.environment is required. Please set it in values.yaml or with --set logging.environment=<value>" }}
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
      value: {{ .Values.logging.region | quote }}
    - name: LOG_STREAM_NAME
      valueFrom:
        configMapKeyRef:
          name: worker
          key: LOG_STREAM_NAME
  securityContext:
    runAsNonRoot: false
    runAsUser: 1020
    runAsGroup: 1010
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
runAsUser: 1020
runAsGroup: 1010
fsGroup: 1010
fsGroupChangePolicy: OnRootMismatch
{{- end -}}

{{- define "logging.dir" -}}
{{ printf "/var/log/backline" }}
{{- end -}}

{{- define "logging.roleArn" -}}
{{- if eq .Values.logging.environment "production" -}}
arn:aws:iam::314146328431:role/OnPremOtelShipRole
{{- else -}}
arn:aws:iam::580550010989:role/OnPremOtelShipRole
{{- end -}}
{{- end -}}
