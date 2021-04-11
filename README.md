# dropbox-docker

The Dropbox client packaged up as a Docker container.
This is blatantly stolen from: https://github.com/otherguy/docker-dropbox

I want to retain control of the container that has access to my Dropbox account so I maintain a separate version and manually update it to match upstream.

# CI/CD

Commits pushed to the `main` branch trigger a build and deploy to `marekl/homelab` which is monitored by ArgoCD and deployed to PineNAS.
