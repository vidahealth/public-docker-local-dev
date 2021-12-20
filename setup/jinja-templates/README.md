These templates are used by either first-time-setup.sh or environment-update.sh
to configure the environment based on which services the developer wants to run

Developer Instructions when updating these templates
---
Remember that the environment-config.yaml is only updated by users running first-time-setup.sh
They will likely manually copy paste from that file sporadically, if they need something new and fancy

This means that all changes to the jinja templates should be backwards compatible with
old environment-config.yaml files.  You should not assume a value is present in the 
yaml just because you added it to environment-config.yaml.jinja.

This is why the environment-config prefers lists of services, instead of top level keys
for them, as it makes it easier to write the jinja template to handle if the value is missing

