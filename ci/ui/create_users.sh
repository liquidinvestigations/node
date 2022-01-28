#!/bin/sh -ex
cat > /tmp/create-users.py <<EOF
from django.contrib.auth import get_user_model
User = get_user_model()
admin = User.objects.create_user('admin', 'admin@example.com', '$TEST_ADMIN_PASSWORD')
admin.is_superuser = True
admin.is_staff = True
admin.save()
print(admin)
john = User.objects.create_user('john', 'john@thebeatles.com', '$TEST_ADMIN_PASSWORD')
print(john)
john.save()
EOF

cat /tmp/create-users.py |  ./liquid dockerexec liquid:core ./manage.py shell


./liquid dockerexec hoover:search ./manage.py shell <<EOF
from hoover.search.models import Collection
Collection.objects.update(public=True)
EOF
