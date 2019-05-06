{% macro migration_reschedule() %}
  reschedule {
    attempts = 10
    interval = "5m"
    delay = "5s"
    delay_function = "exponential"
    max_delay = "30s"
  }
{% endmacro %}
