job "liquid-createuser" {
  datacenters = ["dc1"]
  type = "batch"
  priority = 60

  parameterized {
    meta_required = ["USERNAME"]
    }

  group "createuser" {
    task "script" {
      leader = true

      driver = "raw_exec"

      config {
        command = "sh"
        args    = ["local/createuser.sh"]
      }

      template {
        destination = "local/create_rocket_user.py"
        perms = "755"
        data = <<-EOF
        import requests
        import sys
        {{- range service "rocketchat-app" }}
        url = 'http://{{.Address}}:{{.Port}}/'
        {{- end }}
        {{- with secret "liquid/rocketchat/adminuser" }}
        data = {"user": "rocketchatadmin", "password": "{{.Data.pass }}"}
        print("{{.Data.pass }}")
        {{- end }}
        print(url)
        response = requests.post(url + 'api/v1/login', data=data).json()
        _id = response.get('data').get('me').get('_id')
        token = response.get('data').get('authToken')
        username = sys.argv[1]
        headers = {'X-Auth-Token': token, 'X-User-Id': 'Ybn6dFwcoFnyfrjhk', 'Content-type': 'application/json'}
        data = '{"name": "%s", "email": "%s@liquid.example.org", "password": "pass", "username": "%s", "verified": true}' % (username, username, username)
        print(sys.argv[1])
        print(headers)
        print(data)
        print(_id, token)
        response = requests.post(url + 'api/v1/users.create', headers=headers, data=data)
        print(response.content)
        response = requests.post(url + '/api/v1/logout', headers=headers)
        print(response.content)
        EOF
      }

      template {
        destination = "local/createuser.sh"
        perms = "755"
        data = <<-EOF
          #!/bin/sh
          apt-get install pip
          pip install requests
          set -ex
          hypothesis_users="$(${exec_command('hypothesis-deps:pg', 'psql', '-U', 'hypothesis', 'hypothesis', '-c', "'COPY (SELECT username FROM public.user) TO stdout WITH CSV;'")})"
          ${exec_command('hoover:search', './manage.py', 'createuser', '${NOMAD_META_USERNAME}')}  
          echo "Creating rocketchat user ${getstr('${NOMAD_META_USERNAME}')}"
          python local/create_rocket_user.py ${getstr('${NOMAD_META_USERNAME}')} 
          ${exec_command('hypothesis:hypothesis', '/local/createuser.py', '${NOMAD_META_USERNAME}', '"$hypothesis_users"')}  
          echo $PWD
          echo $(ls)
          echo $?
        EOF
      }
    }
  }
}