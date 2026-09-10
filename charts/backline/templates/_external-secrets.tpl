{{/*
Fallbacks below repeat the values.yaml defaults on purpose: `helm upgrade --reuse-values`
keeps the previous release's defaults, so keys new to this chart version arrive empty.
*/}}
{{- define "backline.externalSecret.apiVersion" -}}
{{- default "external-secrets.io/v1" (.Values.externalSecrets).apiVersion -}}
{{- end -}}

{{/*
Spec fields shared by every chart ExternalSecret. `cfg` is one externalSecrets.<secret>
block; its own secretStoreRef / refreshInterval override the chart-wide defaults.
*/}}
{{- define "backline.externalSecret.specCommon" -}}
{{- $defaults := .root.Values.externalSecrets -}}
{{- $defaultStore := default (dict) $defaults.secretStoreRef -}}
{{- $override := default (dict) .cfg.secretStoreRef -}}
{{- $name := default $defaultStore.name $override.name -}}
{{- $kind := default (default "SecretStore" $defaultStore.kind) $override.kind -}}
{{- if not $name -}}
{{- fail (printf "%s.enabled=true requires a secret store: set externalSecrets.secretStoreRef.name or %s.secretStoreRef.name" .path .path) -}}
{{- end -}}
refreshInterval: {{ default "1h" (default $defaults.refreshInterval .cfg.refreshInterval) }}
secretStoreRef:
  name: {{ $name }}
  kind: {{ $kind }}
{{- end -}}

{{/*
remoteRef for one ExternalSecret data entry, passed through verbatim so any ESO field
(property, version, decodingStrategy, ...) is accepted.
*/}}
{{- define "backline.externalSecret.remoteRef" -}}
{{- if not (.remoteRef).key -}}
{{- fail (printf "%s.remoteRef.key is required" .path) -}}
{{- end -}}
remoteRef:
  {{- toYaml .remoteRef | nindent 2 }}
{{- end -}}
