If you'd like to contribue to this project, there are several different methods:

- Submit a [Pull Request](https://www.github.com/PlagueHO/LabBuilder/pulls) against the GitHub repository, containing:
  - Bug fixes
  - Enhancements
  - New sample Labs
  - DSC library configurations
  - Documentation enhancements
  - Continuous integration & deployment enhancements
  - Unit tests
- Perform user testing and validation, and report bugs on the [Issue Tracker](https://www.github.com/PlagueHO/LabBuilder/issues)
- Raise awareness about the project through [Twitter](https://twitter.com/#PowerShell), [Facebook](https://facebook.com), and other social media platforms

Before working on any enhancement, submit an Issue describing the proposed enhancement. Someone may already be working on the same thing. It also allows other contributors to comment on the proposal.

Alternately, feel free to post on the [LabBuilder Gitter Chat at https://gitter.im/PlagueHO/LabBuilder](https://gitter.im/PlagueHO/LabBuilder). This is also a great place to just say Hi, ask any questions you might have or get help.

If you're new to Git revision control, and the GitHub service, it's suggested that you learn about some basic Git fundamentals, and take an overview of the GitHub service offerings.

# Contribution Guidelines

Different software developers have different styles. If you're interested in contributing to this project, please review the following guidelines. 
While these guidelines aren't necessarily "set in stone," they should help guide the essence of the project, to ensure quality, user satisfaction (*delight*, even), and success.

## Project Structure

- The module manifest (`.psd1` file) must explicitly denote which functions are being exported. No wildcards allowed.
- Private, helper functions should exist under `/LabBuilder/Libs/`.
- Publicly accessible functions should exist in `/LabBuilder/LabBuilder.psm1`.
  - This may get broken down into seperate files in future.
- Use comment-based help inside the function definition, before the `[CmdletBinding()]` attribute and parameter block
- All functions must declare the `[CmdletBinding()]` attribute.

## Style guidelines

When contributing to any PowerShell repositories, please follow the following [Style Guidelines](/.github/STYLGUIDELINES.md)

## Lifecycle of a pull request

* **Always create pull requests to the `dev` branch of the repository**. 
For more information, learn about our [branch structure](#branch-structure).

![Github-PR-dev.png](Images/Github-PR-dev.png)

* Add meaningful title of the PR describing what change you want to check in. Don't simply put: "Fixes issue #5". Better example is: "Added Ensure parameter to xFile resource. Fixes #5". 

* When you create a pull request, fill out the description with a summary of what's included in your changes. 
If the changes are related to an existing GitHub issue, please reference the issue in pull request title or description (e.g. ```Closes #11```). See [this](https://help.github.com/articles/closing-issues-via-commit-messages/) for more details.

* Include an update in the [/LabBuilder/Docs/ChangeList.md](/LabBuilder/Docs/ChangeList.md) file in your pull request to reflect changes for future versions changelog. Put them in `Unreleased` section (create one if doesn't exist). This would simplify the release process for Maintainers. Example:
    ```
    ### Unreleased
    
    -  Added support for `-FriendlyName` in `Update-xDscResource`.
    ```
    Please use past tense when describing your changes: 
    
      * Instead of "Adding support for Windows Server 2012 R2", write "Added support for Windows Server 2012 R2".
    
      * Instead of "Fix for server connection issue", write "Fixed server connection issue".
    
    Also, if change is related to specific resource, please prefix the description with the resource name:
    
      * Instead of "New parameter 'ConnectionCredential' in MEMBER_WEBSERVER.DSC.PS1", write "DSCLibrary\MEMBER_WEBSERVER.DSC.PS1: added parameter 'ConnectionCredential'"
    
* After submitting your pull request, our CI system (Appveyor) [will run a suite of tests](#appveyor) and automatically update the status of the pull request.
* After a successful test pass, the module's maintainers will do a code review, commenting on any changes that might need to be made. If you are not designated as a module's maintainer, feel free to review others' Pull Requests as well, additional feedback is always welcome (leave your comments even if everything looks good - simple "Looks good to me" or "LGTM" will suffice, so that we know someone has already taken a look at it)! 
* Once the code review is done, all merge conflicts are resolved, and the Appveyor build status is passing, a maintainer will merge your changes.

## AppVeyor

We use [AppVeyor](http://www.appveyor.com/) as a continious integration (CI) system.

![AppVeyor-Badge-Green.png](Images/AppVeyor-Badge-Green.png)

This badge is **clickable**, you can open corresponding build page with logs, artifacts and tests results.
From there you can easily navigate to the whole build history.

AppVeyor builds and runs tests on every pull request and provides quick feedback about it.

![AppVeyor-Github](Images/AppVeyor-Github.png)

These green checkboxes and red crosses are **clickable** as well. 
They will bring you to the corresponding page with details. 

## Testing

- Any changed code should not cause Unit Tests to fail.
- Any new code should have Unit tests created for it.
- Test files should follow the file structure of the file being tested (e.g. tests for /LabBuilder/Libs/vms.ps1 should be in /LabBuilder/Tests/Unit/Libs/vms.tests.ps1).
- Unit Test files should exist under `/Tests/Unit`.
- Integration Test files should exist under `/Tests/Integration'.
  - There are currently no integration tests (but there will be at some point).

## Branch structure

We are using a [git flow](http://nvie.com/posts/a-successful-git-branching-model/) model for development.
We recommend that you create local working branches that target a specific scope of change. 
Each branch should be limited to a single feature/bugfix both to streamline workflows and reduce the possibility of merge conflicts.
![git flow picture](http://nvie.com/img/git-model@2x.png)

