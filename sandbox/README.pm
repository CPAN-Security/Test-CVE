# Sandbox

The folder `sandbox` is a place where the author (and other maintainers)
can put files or scripts that ease the process of development.

## Distribution

The top-level `Makefile.PL` might have a non-standard rule I use to
prepare a new release:

```
$ make tgzdist
```

## Extra checks

The current state is quite neutral, but it is likely to extend to the
use of the scripts in `sandbox`, so

```
$ perl sandbox/genMETA.pl --check
```

can do all the external checking like version-consistency, syntax matching
declared (perl) versions, required, recommended and suggested CPAN modules
and CVE checks on the dist itself.

I use a lot of personalized stuff to make sure a new tarball meets most
of the commonly accepted standards. Much of those have been described in
L<Release::CheckList>
