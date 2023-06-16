{% from '_lib.hcl' import shutdown_delay, continuous_reschedule, group_disk, task_logs with context -%}

job "rocketchat" {
  datacenters = ["dc1"]
  type = "service"
  priority = 97

  spread { attribute = {% raw %}"${attr.unique.hostname}"{% endraw %} }

  group "app" {
    ${ continuous_reschedule() }
    ${ group_disk() }

    task "rocketchat" {
      ${ task_logs() }
      driver = "docker"
      config {
        image = "${config.image('rocketchat')}"
        args = ["node", "/local/main.js"]
        labels {
          liquid_task = "rocketchat-app"
        }
        port_map {
          web = 3000
        }
        memory_hard_limit = 5000
      }
      template {
        # WARNING: no empty lines, comments or anything else in this line. parsing and overwriting is done in script below...
        data = <<-EOF
          MONGO_URL=mongodb://{{ env "attr.unique.network.ip-address" }}:${config.port_rocketchat_mongo}/meteor
          MONGO_OPLOG_URL=mongodb://{{ env "attr.unique.network.ip-address" }}:${config.port_rocketchat_mongo}/local?replSet=rs01
          ROOT_URL=${config.liquid_http_protocol}://rocketchat.${config.liquid_domain}
          {{- with secret "liquid/rocketchat/adminuser" }}
            ADMIN_USERNAME={{.Data.username | toJSON }}
            ADMIN_PASS={{.Data.pass | toJSON }}
          {{- end }}
          ADMIN_EMAIL=admin@example.com

          Organization_Name=Liquid Investigations
          Organization_Type=Nonprofit
          Size=1-10 people
          Industry=Other
          Country=Worldwide
          Website=https://example.org
          Server_Type=Private Team
          Site_Name=${config.liquid_title}
          Site_Url=${config.liquid_http_protocol}://rocketchat.${config.liquid_domain}

          OVERWRITE_SETTING_Organization_Name=Liquid Investigations
          OVERWRITE_SETTING_Organization_Type=Nonprofit
          OVERWRITE_SETTING_Size=1-10 people
          OVERWRITE_SETTING_Industry=Other
          OVERWRITE_SETTING_Country=Worldwide
          OVERWRITE_SETTING_Website=https://example.org
          OVERWRITE_SETTING_Server_Type=Private Team
          OVERWRITE_SETTING_Site_Name=${config.liquid_title}
          OVERWRITE_SETTING_Site_Url=${config.liquid_http_protocol}://rocketchat.${config.liquid_domain}

          OVERWRITE_SETTING_Accounts_OAuth_Custom-Liquid=true
          OVERWRITE_SETTING_Accounts_OAuth_Custom-Liquid-token_path=http://{{ env "attr.unique.network.ip-address" }}:${config.port_lb}/_core/o/token/
          OVERWRITE_SETTING_Accounts_OAuth_Custom-Liquid-identity_path=http://{{ env "attr.unique.network.ip-address" }}:${config.port_lb}/_core/accounts/profile
          OVERWRITE_SETTING_Accounts_OAuth_Custom-Liquid-authorize_path=${config.liquid_core_url}/o/authorize/
          OVERWRITE_SETTING_Accounts_OAuth_Custom-Liquid-scope=read
          {{- with secret "liquid/rocketchat/app.oauth2" }}
            OVERWRITE_SETTING_Accounts_OAuth_Custom-Liquid-id={{.Data.client_id | toJSON }}
            OVERWRITE_SETTING_Accounts_OAuth_Custom-Liquid-secret={{.Data.client_secret | toJSON }}
          {{- end }}
          OVERWRITE_SETTING_Accounts_OAuth_Custom-Liquid-button_label_color=yellow
          OVERWRITE_SETTING_Accounts_OAuth_Custom-Liquid-button_label_text=LIQUID LOGIN - CLICK HERE TO GET IN
          OVERWRITE_SETTING_Accounts_OAuth_Custom-Liquid-login_style=redirect
          OVERWRITE_SETTING_Accounts_OAuth_Custom-Liquid-map_channels=false
          OVERWRITE_SETTING_Accounts_OAuth_Custom-Liquid-merge_roles=true
          OVERWRITE_SETTING_Accounts_OAuth_Custom-Liquid-merge_users=true
          OVERWRITE_SETTING_Accounts_OAuth_Custom-Liquid-name_field=name
          OVERWRITE_SETTING_Accounts_OAuth_Custom-Liquid-roles_claim=roles
          OVERWRITE_SETTING_Accounts_OAuth_Custom-Liquid-show_button=true
          OVERWRITE_SETTING_Accounts_OAuth_Custom-Liquid-token_sent_via=header
          OVERWRITE_SETTING_Accounts_OAuth_Custom-Liquid-username_field=id

          OVERWRITE_SETTING_Show_Setup_Wizard=completed
          OVERWRITE_SETTING_registerServer=false
          OVERWRITE_SETTING_Accounts_AllowEmailNotifications=false
          OVERWRITE_SETTING_Accounts_AllowPasswordChange=false
          OVERWRITE_SETTING_Accounts_AllowPasswordChangeForOAuthUsers=false
          OVERWRITE_SETTING_Accounts_ForgetUserSessionOnWindowClose=false
          OVERWRITE_SETTING_Accounts_PasswordReset=false
          OVERWRITE_SETTING_Accounts_RegistrationForm=Disabled
          OVERWRITE_SETTING_Allow_Marketing_Emails=false
          OVERWRITE_SETTING_Allow_Save_Media_to_Gallery=false
          OVERWRITE_SETTING_FEDERATION_Enabled=false
          OVERWRITE_SETTING_FileUpload_Enabled=false
          OVERWRITE_SETTING_IRC_Enabled=false
          OVERWRITE_SETTING_Layout_Sidenav_Footer=<a href="/home"><img src="assets/favicon.svg"/></a><a href="${config.liquid_core_url}"><h1 style="font-size:77%;float:right;clear:both; color:#aaa">&#8594; ${config.liquid_title}</h1></a>
          OVERWRITE_SETTING_Message_VideoRecorderEnabled=false
          {% if config.rocketchat_enable_push %}
            OVERWRITE_SETTING_Push_enable=true
            OVERWRITE_SETTING_Push_enable_gateway=true
            OVERWRITE_SETTING_Push_gateway=https://gateway.rocket.chat
            OVERWRITE_SETTING_Push_production=true
            OVERWRITE_SETTING_Register_Server=true
            OVERWRITE_SETTING_Cloud_Service_Agree_PrivacyTerms=true
          {% else %}
            OVERWRITE_SETTING_Push_enable=false
            OVERWRITE_SETTING_Push_enable_gateway=false
            OVERWRITE_SETTING_Push_gateway=${config.liquid_core_url}
            OVERWRITE_SETTING_Push_production=false
            OVERWRITE_SETTING_Register_Server=false
            OVERWRITE_SETTING_Cloud_Service_Agree_PrivacyTerms=false
          {% endif %} 
          OVERWRITE_SETTING_UI_Allow_room_names_with_special_chars=true
          OVERWRITE_SETTING_UserData_EnableDownload=false
          OVERWRITE_SETTING_Document_Domain=${config.liquid_domain}
          OVERWRITE_SETTING_Accounts_LoginExpiration=${config.rocketchat_autologout_days}
          {% if config.rocketchat_show_login_form %}
            OVERWRITE_SETTING_Accounts_ShowFormLogin=true
          {% else %}
            OVERWRITE_SETTING_Accounts_ShowFormLogin=false
          {% endif %}
          OVERWRITE_SETTING_Accounts_AllowEmailChange=false
          OVERWRITE_SETTING_Accounts_AllowUsernameChange=false
          OVERWRITE_SETTING_Accounts_Send_Email_When_Activating=false
          OVERWRITE_SETTING_Accounts_Send_Email_When_Deactivating=false
          OVERWRITE_SETTING_Accounts_RequirePasswordConfirmation=false
          OVERWRITE_SETTING_Accounts_Verify_Email_For_External_Accounts=true
          OVERWRITE_SETTING_Accounts_TwoFactorAuthentication_Enabled=false
          OVERWRITE_SETTING_Accounts_TwoFactorAuthentication_By_Email_Enabled=false
          OVERWRITE_SETTING_Accounts_TwoFactorAuthentication_By_Email_Auto_Opt_In=false
          OVERWRITE_SETTING_Accounts_TwoFactorAuthentication_Enforce_Password_Fallback=false
          OVERWRITE_SETTING_Accounts_Default_User_Preferences_notificationsSoundVolume=66
          OVERWRITE_SETTING_Accounts_EmailVerification=false
          OVERWRITE_SETTING_E2E_Enable=false
          OVERWRITE_SETTING_Custom_Script_On_Logout=window.location.href="${config.liquid_core_url}/accounts/logout/?next=/";
          OVERWRITE_SETTING_DeepLink_Url=${config.liquid_http_protocol}://rocketchat.${config.liquid_domain}
          OVERWRITE_SETTING_CDN_PREFIX_ALL=false

          SETTINGS_BLOCKED=Show_Setup_Wizard,registerServer,Accounts_PasswordReset,Accounts_RegistrationForm,Allow_Marketing_Emails,Allow_Save_Media_to_Gallery,Cloud_Service_Agree_PrivacyTerms,FEDERATION_Enabled,FileUpload_Enabled,IRC_Enabled,Layout_Sidenav_Footer,Message_VideoRecorderEnabled,Push_enable,Push_enable_gateway,Push_gateway,Register_Server,UI_Allow_room_names_with_special_chars,UserData_EnableDownload,Document_Domain,Push_production,Accounts_LoginExpiration,Accounts_AllowUsernameChange,Accounts_Send_Email_When_Activating,Accounts_Send_Email_When_Deactivating,Accounts_RequirePasswordConfirmation,Accounts_Verify_Email_For_External_Accounts,Accounts_TwoFactorAuthentication_Enabled,Accounts_TwoFactorAuthentication_By_Email_Enabled,Accounts_TwoFactorAuthentication_By_Email_Auto_Opt_In,Accounts_TwoFactorAuthentication_Enforce_Password_Fallback,Accounts_Default_User_Preferences_notificationsSoundVolume,E2E_Enable,DeepLink_Url

        EOF
        # OVERWRITE_SETTING_Accounts_OAuth_Custom-Liquid-groups_claim=roles
        destination = "local/liquid.env"
      }
      template {
        data = <<EOF
          var fs = require('fs');
          var dotenv = ('' + fs.readFileSync('/local/liquid.env')).trim();
          for (const a of dotenv.split(/\n/)) {
            if (a.trim() == "") {
              continue;
            }
            [_,k,v] = a.trim().match(/^([^=]+)=(.*)/);
            var noquotes = v.match(/^"(.*)"$/);
            if (noquotes) v = noquotes[1];
            process.env[k] = v;
          }
          require('/app/bundle/main.js');
        EOF
        destination = "local/main.js"
      }
      resources {
        memory = 1200
        cpu = 300
        network {
          mbits = 1
          port "web" {}
        }
      }
      service {
        name = "rocketchat-app"
        port = "web"
        tags = [
          "traefik.enable=true",
          "traefik.frontend.rule=Host:${'rocketchat.' + liquid_domain}",
          "fabio-:${config.port_rocketchat} proto=tcp"
        ]
        check {
          name = "http"
          initial_status = "critical"
          type = "http"
          path = "/api/info"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
          header {
            Host = ["rocketchat.${liquid_domain}"]
          }
        }
        check_restart {
          limit = 5
          grace = "990s"
        }
      }
    }
  }
}
