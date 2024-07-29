# Contributing

Feel free to dive in! [Open](https://github.com/xeon-protocol/xeon-testnet/issues/new) an issue, [start](https://github.com/xeon-protocol/xeon-testnet/discussions/new) a discussion or submit a PR. For any informal concerns or feedback, please join our [Telegram Group](https://t.me/XeonProtocolPortal).

Contributions to Xeon Protocol are welcome by anyone interested in writing more tests, improving readability, optimizing for gas efficiency, or extending the protocol via new features.

## Prerequisites

You will need the following packages to get started.

[![git](https://img.shields.io/badge/git-any-darkgreen)](https://git-scm.com/downloads) [![npm](https://img.shields.io/badge/npm->=_6-darkgreen)](https://npmjs.com/) [![Foundry](https://img.shields.io/badge/Foundry-v0.2.0-orange)](https://book.getfoundry.sh/)

In addition, familiarity with [Solidity](https://soliditylang.org/) is a requisite.

## Set Up

Clone this repository including submodules:

```shell
git clone --recurse-submodules -j8 git@github.com:xeon-protocol/xeon-testnet.git
```

Then, ensure Foundry is installed and initialized inside the project directory:

```shell
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

Install the required dependencies:

```shell
forge install
```

## Environment variables

### Local Setup

First, copy the template environment file into one for local use:

```shell
cp .env.sample .env.local
```

Populate it with the appropriate environment values. You need to provide a mnemonic phrase/private key and a few API keys.

⚠️ **NOTE:** Only put sensitive data in the `.env.local` file, which is ignored by git. **DO NOT** enter sensitive data in `.env.sample`.

## Pull Requests

All work should be done on it's own branch. Once you are done working on a branch, create a pull request to merge it back into `main`.

When making a pull request, ensure that:

- All tests pass.
  - Fork testing requires environment variables to be set up in the forked repo.
- Code coverage remains the same or greater.
- All new code adheres to the style guide:
  - All lint checks pass
  - Code is thoroughly commented with NatSpec where relevant.
- If making a change to the contracts:
  - Gas snapshots are provided and demonstrate an improvement (or an acceptable deficit given other improvements).
  - Reference contracts are modified correspondingly if relevant.
  - New tests are included for all new features or code paths.
- A descriptive summary of the PR has been provided.
- Assign reviewers to the PR and request a **code review**.
- Address any feedback or requested changes promptly.

## Additional Guidelines

In order to maintain high quality code that is easy to collaborate on, please make sure to stick to best practices. Expectations for code management are listed below.

## Branching Strategy

- Always create a new branch from `main` for any new feature or bug fix.
- To avoid merge conflicts, each branch should only serve a single purpose.
- Use descriptive branch names that clearly indicate the purpose of the branch, such as:

```shell
`audit/staking`
`feature/update-hedge-settlement`
`script/set-admin-roles`
```

## Code Reviews

- Reviewers should provide constructive feedback and look for potential issues or improvements.
- Make sure to test the changes locally before approving the PR.
- Only approve PRs that meet our quality standards and follow our coding guidelines.

## Merging

- Once the PR is approved and all checks pass, squash and merge into `main`.
  - Use **squash and merge** to keep the commit history clean (unless the branch contains logically distinct commits that should be preserved).

## Maintaining a Clean Codebase

- Regularly pull the latest changes from `main` into your working branches to avoid conflicts.
- After merging a branch, delete it to keep the repo clean.
- Document any significant changes or new features in our project documentation (`README.md` and associated files).

## Additional Guidelines

- **Commit Messages:** Write clear and concise commit messages that accurately describe the changes made. Use the imperative mood and present tense (e.g., `"Fix bug in user authentication"`).
- **Coding Standards:** Follow our coding standards and style guides to ensure consistency across the codebase. Refer to the project's documentation for specific guidelines.
- **Testing:** Write and maintain unit and integration tests for all new features and bug fixes. Ensure that all tests pass before submitting a pull request.
- **Documentation:** Keep the documentation up-to-date with any code changes. This includes comments within the code, as well as external documentation like the `README.md` and any additional guides.

---

# Commit Guidelines

Xeon Protocol uses **The Conventional Commits** specification across the codebase. Refer to the complete [documentation](https://www.conventionalcommits.org/en/v1.0.0/#summary) for details.

Commit messages should be structured as follows:

```
<type>(optional scope): <description>

[optional body]

[optional footer(s)]
```

This commit structure communicates intent to consumers of the codebase, and automatically populates our CHANGELOG which helps with version control, and ensures that we can easily trace the commit history.

## Type

Main commit types are `fix` for bug patches and `feat` for new features. Other types are allowed, but must be one of the following:

`build:` a change that affect the build system or external dependencies (example scopes: `scripts`, `foundry`, `npm`, `docker`)

`chore:` a code change that neither fixes a bug nor adds a feature

`docs:` documentation only changes

`feat:` a new feature

`fix:` a bug fix

`perf:` a code change that improves performance

`style:` a change that does not affect the meaning of the code (white-space, formatting, missing semi-colons, etc)

`test:` adding missing tests or correcting existing tests

## Scope

Optional field that is only relevant if changes are made in a repository that has multiple packages.

## Description

A succinct description of the change:

- use the imperative, present tense: _"change"_ not _"changed"_ nor _"changes"_
- don't capitalize the first letter
- no dot (.) at the end

## Body

Just as in the subject, use the imperative, present tense: **_"change"_** not _"changed"_ nor _"changes"_. The body should include the motivation for the change and contrast this with previous behavior.

## Footer

The footer contains any info about **Breaking Changes** and is the place to reference any GitHub issues that the commit **CLOSES**.

- `BREAKING CHANGE:` footer or appends a `!` after the type/scope introduces a breaking change. This correlates to a new `MAJOR` version and can be associated with any type.

## Example Commits

Commit message with no body

```
docs: add commit guidelines to CHANGELOG
```

Commit message with multi-paragraph body and multiple footers

```
feat(wallet): multi-chain balance display

Introduce a multi-chain native wallet modal to display total user balance across networks. Dismiss dust.

Remove obsolete dependencies for multiple networks.

Reviewed-by: Jon
Refs: #123
```

If a commit fixes a specific issue, indicate the number after the description.

```
fix: resolve network not switching (#69)
```

---

## Notice

These guidelines apply to all code in the Xeon Protocol codebase and this `CONTRIBUTING.md` file should accompany every repository in the organization.
