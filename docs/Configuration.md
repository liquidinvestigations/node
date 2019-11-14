# Configuration

The Liquid bundle can be configured by setting options in `liquid.ini`. See the [reference configuration file](../examples/liquid.ini) for a description of the different options.


## Maintenance
During maintenance, you may decide to allow only administrators to log in. Set
this flag in `liquid.ini` then deploy:

```ini
[liquid]
auth_staff_only = true
```

To invalidate any existing login session, run `killsessions`:

```shell
./liquid shell liquid-core ./manage.py killsessions
```


## Versions
The liquid bundle comes with a `versions.ini` file with a known set of working
versions. You can override them in `liquid.ini`, see `examples/liquid.ini` for
more information.

For this repo and liquid+hoover dependencies, we follow [semver][] when tagging
new versions, and keep `versions.ini` up to date with a known compatible
working set of version tags.

[semver]: https://semver.org/
