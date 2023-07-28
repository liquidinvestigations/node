#!/bin/bash
set -ex

cd "$(dirname ${BASH_SOURCE[0]})/.."

(
cat <<EOF

from django.db.models import F
from snoop.data.collections import ALL
from snoop.data.models import Task

print()
print('longest tasks:')
max_s = 0
for name, collection in ALL.items():
    with collection.set_current():
        order_expr = (
            F('date_finished') - F('date_started')
        ).desc(nulls_last=True)
        q = Task.objects.filter(date_finished__isnull=False)
        q = q.order_by(order_expr)[:3]
        for task in q:
            dur = task.date_finished - task.date_started
            dur_s = dur.total_seconds()
            if dur_s > max_s:
                max_s = dur_s
            msg = f"col='{name}' func='{task.func}' {dur}"
            print(msg)
print('max task:  ', int(max_s), 'sec   =', int(max_s/3600), 'h')
EOF
) | ./liquid dockerexec hoover:snoop ./manage.py shell
