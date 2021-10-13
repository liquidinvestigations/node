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
        # get rockatchat address and password
        {{- range service "rocketchat-app" }}
        url = 'http://{{.Address}}:{{.Port}}/'
        {{- end }}
        {{- with secret "liquid/rocketchat/adminuser" }}
        data = {"user": "rocketchatadmin", "password": "{{.Data.pass }}"}
        {{- end }}
        domain = "${liquid_domain}"
        # login to receive a token to authenticate with the api
        response = requests.post(url + 'api/v1/login', data=data).json()
        _id = response.get('data').get('me').get('_id')
        token = response.get('data').get('authToken')
        username = sys.argv[1]
        headers = {'X-Auth-Token': token, 'X-User-Id': _id, 'Content-type': 'application/json'} # needed to authenticate
        data = '{"name": "%s", "email": "%s@%s", "password": "pass", "username": "%s", "verified": true}' % (username, username, domain, username)
        # call the rocketchat api to create user
        response = requests.post(url + 'api/v1/users.create', headers=headers, data=data)
        if response.status_code != 200:
           print("An error occured!")
           print("Got the following response from rocketchat:")
           print(response.content)
        else:
           print("Created Rocketchat user " + username + ".")
        requests.post(url + '/api/v1/logout', headers=headers)
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
          liquid_domain="${liquid_domain}"
          echo "Creating user ${getstr('${NOMAD_META_USERNAME}')} for all enabled apps."
          {% if config.is_app_enabled('hoover') %}
          echo "Creating Hoover user..."
          ${exec_command('hoover:search', './manage.py', 'createuser', '${NOMAD_META_USERNAME}')}  
          {% endif %}
          {% if config.is_app_enabled('hypothesis') %}
          echo "Creating Hypothesis user..."
          hypothesis_users="$(${exec_command('hypothesis-deps:pg', 'psql', '-U', 'hypothesis', 'hypothesis', '-c', "'COPY (SELECT username FROM public.user) TO stdout WITH CSV;'")})"
          ${exec_command('hypothesis:hypothesis', '/local/createuser.py', '${NOMAD_META_USERNAME}', '"$hypothesis_users"')}  
          {% endif %}
          {% if config.is_app_enabled('rocketchat') %}
          echo "Creating Rocketchat user..."
          python local/create_rocket_user.py ${getstr('${NOMAD_META_USERNAME}')} 
          {% endif %}
          {% if config.is_app_enabled('codimd') %}
          echo "Creating CodiMD user..."
          ${exec_command('codimd:codimd', '/codimd/bin/manage_users', '--profileid=${NOMAD_META_USERNAME}', '--domain="$liquid_domain"')}  
          {% endif %}
        EOF
      }
    }
  }
}