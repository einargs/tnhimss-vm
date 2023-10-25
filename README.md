# TODO
- [X] test with just the vm
- [ ] setup neo4j service for query
- [X] package query site
- [X] package query app
- [X] write query service
- [X] import query stuff
- [X] switch back from local paths
- [ ] Update README.md

# Update inputs
To update one of the inputs you can just do:
```
nix flake lock --update-input <input-name>
```

# Deployment
See visitNotes TODO for info about deploying an azure machine from scratch.

However, you can also simply ssh into the machine and run
```
sudo nixos-rebuild switch --flake ./tnhimss-vm#azure-vm
```
You may prefer to run this command inside of a tmux window so that if the ssh
connection gets interrupted you can quickly recover.

You should also be able to remotely deploy the build using `nixos-rebuild`, but
I haven't tested it at all.
