job "xwiki-setup" {
  datacenters = ["dc1"]
  priority = 99

  type = "batch"

  group "setup" {
    task "setup" {
      leader = true
      driver = "raw_exec"

      config {
        command = "/bin/bash"
        args = [
                "local/setup-xwiki.sh",
        ]
      }
      env {
      }

      template {
        data = <<EOF
          {{- with secret "liquid/xwiki/xwiki.superadmin" }}
            PASSWORD = {{.Data.secret_key | toJSON }}
          {{- end }}
        NOMAD_URL = "${config.nomad_url}"
        XWIKI_URL = "http://{{ env "attr.unique.network.ip-address" }}:${config.port_xwiki}"
EOF

        destination = "local/exec.env"
        env         = true
      }

      template {
        destination = "local/setup-xwiki.sh"
        perms = "755"
        data = <<-EOF
{% include 'scripts/setup-xwiki.sh' %}
        EOF
      }


      template {
        data = <<EOF
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<jobRequest xmlns="http://www.xwiki.org">
  <id>
    <element>extension</element>
    <element>provision</element>
    <element>796fb04f-b095-4db8-a3ec-fa03f22051f8</element>
  </id>
  <interactive>false</interactive>
  <remote>false</remote>
  <verbose>true</verbose>
  <property>
    <key>extensions</key>
    <value>
      <list xmlns="" xmlns:ns2="http://www.xwiki.org">
        <org.xwiki.extension.ExtensionId>
          <id>org.xwiki.contrib.oidc:oidc-authenticator</id>
          <version class="org.xwiki.extension.version.internal.DefaultVersion" serialization="custom">
            <org.xwiki.extension.version.internal.DefaultVersion>
              <string>2.13.1</string>
            </org.xwiki.extension.version.internal.DefaultVersion>
          </version>
        </org.xwiki.extension.ExtensionId>
      </list>
    </value>
  </property>
  <property>
    <key>extensions.excluded</key>
    <value>
      <set xmlns="" xmlns:ns2="http://www.xwiki.org"/>
    </value>
  </property>
  <property>
    <key>interactive</key>
    <value>
      <boolean xmlns="" xmlns:ns2="http://www.xwiki.org">false</boolean>
    </value>
  </property>
  <property>
    <key>namespaces</key>
    <value>
      <list xmlns="" xmlns:ns2="http://www.xwiki.org">
        <string>xwiki</string>
      </list>
    </value>
  </property>
</jobRequest>
EOF
        destination = "local/installjobrequest.xml"
      }

      template {
        data = <<EOF
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<object xmlns="http://www.xwiki.org">
    <className>XWiki.StyleSheetExtension</className>
    <property name="name">
        <value>Custom Stylesheet</value>
    </property>
    <property name="code">
        <value><![CDATA[
.menu-horizontal-toggle {
  position: absolute;
  top: 0;
  left: 150px;
  #menu-horizontal-Menu-home-WebHome {
    background-color: #3e79bc;
    box-shadow: none;
  }
}
                        ]]>
                </value>
    </property>
    <property name="use">
        <value>always</value>
    </property>
    <property name="parse">
        <value>0</value>
    </property>
    <property name="cache">
        <value>default</value>
    </property>
    <property name="contentType">
        <value>CSS</value>
    </property>
</object>
        EOF
        destination = "local/installcss.xml"
      }

      template {
        data = <<EOF
<page xmlns="http://www.xwiki.org">
        <title>customcss</title>
        <syntax>xwiki/2.0</syntax>
        <hidden>true</hidden>
</page>
        EOF
        destination = "local/emptypage.xml"
      }

      resources {
        cpu    = 200
        memory = 128
      }
    }
  }
}
