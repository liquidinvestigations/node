{% macro migration_reschedule() %}
  reschedule {
    unlimited = true
    attempts = 0
    delay = "5s"
  }
{% endmacro %}
