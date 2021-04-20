# Development on the Liquid bundle


## Debugging

Set the debug flag in `liquid.ini`:
```ini
[liquid]
debug = on
```

Then redeploy (`./liquid deploy`).

To log into the snoop docker container:
```shell
./liquid shell hoover:snoop
```

## Working on components

In order to work on Hoover Search, Hoover Snoop, or Liquid Core, first clone
the repositories:

```shell
cd repos
./clone.sh https  # or ./clone.sh ssh, based on preference
```

After that, set these flags in your configuration:

```ini
[liquid]
...
mount_local_repos = true

...

version_track = testing
```

And run:
```
./liquid deploy
./autoreload
```

The `autoreload` script will re-run `./liquid deploy --no-update-images
--no-secrets --no-checks` every time there is a relevant code change in the
current directory. The `autoreload` command covers all the repositories from
`repos` as well as the current repository. The `.gitignore` files in every repo
are respected when refreshing; events on ignored files are printed too for
debugging. Finally, the `autoreload` command will debounce running `deploy` by
killing its own child process when a new one is supposed to be created.

The `autoreload` command will not work for the following changes:
- change in containers (because of `--no-update-images`)
- change in secrets (because of `--no-secrets`)

The `autoreload` command does not output failures or errors (because of
`--no-checks`). Use the Nomad UI for viewing logs.


Whenever any of those repos' `master` branches are changed upstream, you must
run `./clone https` again to update the ones you are not working on. The
command will run `git pull --ff-only`, so it won't affect repositories where
there is work in progress. You want to do this every time a minor release is made.



## Removing dead jobs from nomad

In order to remove dead jobs from nomad run the following command:
`./liquid nomadgc`.


## Enabling/disabling applications

Applications can be enabled/disabled on deploy by setting them `on` or `off`
in the `apps` section:
```ini
[apps]
nextcloud = off
```

By default, all applications are started, but this default can also be changed
in the `deploy` section:
```ini
[apps]
default_app_status = off
```


## Running custom jobs

You can deploy your own jobs on the cluster. First, create a nomad job file,
you can use one of the existing `.nomad` files as a starting point. Save it in
the `local` folder, or outside the repository, so that it doesn't interfere
with updates. Then add the job to `liquid.ini`:

```ini
[job:foo]
template = local/foo.nomad
```

Afterwards, run `./liquid deploy`, which will send your job `foo` to nomad.
