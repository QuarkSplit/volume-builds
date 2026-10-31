# Volume native builds

This repository contains the build transport, not the application source.
An owner-dispatched job authenticates and opens an AES-256-GCM source snapshot on a standard hosted Mac.
The key is an Actions secret. Build output is encrypted before upload; only verified release results are published as artifacts.
No pull-request or push event executes a private build.

The encrypted snapshot contains the pinned build instructions, shared Windows frontend, native dependency sources, and starter shelf.
The build checks shared-file SHA-256 digests against the Windows release before producing a downloadable installer.
