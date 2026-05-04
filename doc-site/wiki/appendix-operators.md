# Appendix: quick-start for operators {#appendix}

1. Сначала смотрим `Grafana Overview` по `service/env`
2. Находим симптомы (метрики) → корреляция с логами (OpenSearch/Log Analytics)
3. Переходим к трассам по `trace_id` → идентификация upstream/downstream
4. Создаём/насылаем инцидент (автоматически через ITSM интеграцию)

---

Если нужно, расширю документацию отдельными страницами (AKS specifics, OTel Collector config templates, policy sample с `DeployIfNotExists` параметрами, terraform skeleton под ваш subscription layout).
