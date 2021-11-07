# README

These are reusable Jinja2 templates for [sceptre](https://sceptre.cloudreach.com/2.6.3/) use. Usage:

1. Download this git repo to your sceptre project.

2. Invoke one of the templates from your sceptre config and supply the required variables for the selected templates in `sceptre_user_data` variable, e.g.:

   ```
   template_path: ec2/vpc.yaml.j2
   
   sceptre_user_data:
     project_code: "{{ stack_group_config.project_code }}"
     source_repo_url: !environment_variable SOURCE_REPO_URL
     vpcs:
       - name: mainvpc
         cidr_block: 10.192.0.0/20
         use_ipv6: true
         tags:
           Name: mainvpc
           Project: {{ stack_group_config.project_code }}
   ```

   For more examples please visit https://github.com/harisfauzi/shared-sceptre-template-examples/
   