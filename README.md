# cenv

Chicken 5 virtual environments.

## Description

A single `csi` script, `cenv.scm`, which creates a self-contained Chicken 5 environment in a specified directory. It remembers which Chicken you used to create it, and it keeps its own repository of eggs, which extends that base Chicken.

When the environment is active, `csi` and `csc` and compiled programs use this repository, falling back to the base repository if an extension does not exist. `chicken-install` installs eggs into this new repository. `chicken-uninstall` is limited to the new repository, and `chicken-status` shows both. Generally, everything behaves as you expect.

`cenv` could be useful if:

- You are a regular user using the system Chicken and you have no permissions to, or don't want to, install eggs systemwide.
- You want to test or switch between different versions of eggs, without creating an entire Chicken installation to house them.

## Usage

Initialize an environment by running `cenv.scm` with `csi`, using the `init` verb. The full path of the Chicken you use is permanently stored in the new environment (even if you don't call it with a full path).

    csi -s /path/to/cenv.scm init <directory>
    ~/mychicken/csi -s /path/to/cenv.scm init <directory>
    /path/to/cenv.scm init <directory>

Enter the environment by sourcing `center` (from bash), then running commands.

    source myenv/bin/center
    chicken-install ...

With `cexec` you can run a one-off command in the environment. It will use `/bin/sh`, so you can run it from a weird shell, such as fish.

    ./myenv/bin/cexec chicken-install ...

At the moment, there is no `cexit` to leave a `center`ed environment. You should start a subshell first if you need the ability to exit, or use `cexec`.

## Example -- installing an egg

Nothing up my sleeve, `base64` is not installed:

    $ csi -R base64 -p '(base64-encode "hello")'
    Error: (import) during expansion of (import ...) - cannot import
    from undefined module: base64

Init environment in `~/tmp/myenv`:

    $ cd ~/tmp
    $ csi -s ~/scheme/cenv/cenv.scm init myenv
    Using CHICKEN 5.0.0 in /Users/jim/local/chicken/5.0.0
    Initializing repository in myenv
    New repository path:
    (/Users/jim/tmp/myenv/lib /Users/jim/local/chicken/5.0.0/lib/chicken/9)

Enter the new environment, and install `base64`:

    $ bash                       # Start a subshell
    $ source myenv/bin/center
    $ chicken-install base64
    building srfi-14
      installing srfi-14
    building srfi-13
      installing srfi-14
    building base64
      installing base64

    $ tree myenv/lib
    myenv/lib
    ├── base64.egg-info
    ├── base64.import.so*
    ├── base64.link
    ├── base64.o
    ├── base64.so*
    ├── srfi-13.egg-info
    ├── srfi-13.import.so*
    ├── srfi-13.link
    ├── srfi-13.o
    ├── srfi-13.so*
    ├── srfi-13.types
    ├── srfi-14.egg-info
    ├── srfi-14.import.so*
    ├── srfi-14.link
    ├── srfi-14.o
    ├── srfi-14.so*
    └── srfi-14.types

Run `base64` (still in the new environment):

    $ csi -R base64 -p '(base64-encode "hello")'
    aGVsbG8=

Exit the environment (subshell); `base64` no longer works:

    $ exit
    $ csi -R base64 -p '(base64-encode "hello")'
    Error: (import) during expansion of (import ...) - cannot import
    from undefined module: base64

Note that the `base64` dependencies `srfi-13` and `srfi-14` were installed in your repository as well. If you had them installed in your base Chicken, they would not be installed unless chicken-install deemed it necessary, for example to satisfy a version requirement.

## Example -- two Chickens

Initialize 2 environments, using 2 different versions of Chicken 5. `cexec` and `center` use the Chicken you initialized the environment with.

    $ ~/local/chicken/5.0.0/bin/csi -s ~/scheme/cenv/cenv.scm init c500
    Using CHICKEN 5.0.0 in /Users/jim/local/chicken/5.0.0
    Initializing repository in c500
    New repository path:
    (/Users/jim/tmp/c500/lib /Users/jim/local/chicken/5.0.0/lib/chicken/9)

    $ ~/local/chicken/5.0.1/bin/csi -s ~/scheme/cenv/cenv.scm init c501
    Using CHICKEN 5.0.1 in /Users/jim/local/chicken/5.0.1
    Initializing repository in c501
    New repository path:
    (/Users/jim/tmp/c501/lib /Users/jim/local/chicken/5.0.1/lib/chicken/10)

Run each version of chicken-install using `cexec` and check its version.

    $ ./c500/bin/cexec chicken-install -version
    5.0.0

    $ ./c501/bin/cexec chicken-install -version
    5.0.1

Alternatively you could use `center`:

    $ chicken-install -version          # default chicken in my PATH
    4.12.0

    $ source c501/bin/center
    $ chicken-install -version
    5.0.1

## Technical

Behind the scenes, `cenv` is just manipulating the environment variables `CHICKEN_INSTALL_PREFIX`, `CHICKEN_INSTALL_REPOSITORY`, `CHICKEN_REPOSITORY_PATH` and `PATH`.

## Caveats and TODOs

- `cenv` extends the base Chicken's environment; the new environment is not completely isolated.
- It would be possible to isolate the environment more by copying only a list of known base modules from the base repository into the new repository at initialization time, and omitting the base repository from the repo path.
- Egg shared data may not be found inside a cenv, as (lacking support from the core) every egg hacks together a method of locating its shared data. Special action is taken in `center` to set the chicken-doc repository location correctly. If we turned `cenv` into a library, eggs could use it to standardize finding this data, and we could eliminate special casing.
