<details>
  <summary>Jump to Section</summary>

* [About This Project](#about)
  * [Some Background](#about-background)
  * [How It Works](#about-how-it-works)
* [Current Project Status](#status)
* [Project History](#history)
* [How Can I Help?](#help)
  * [In PowerShell](#help-powershell)
  * [In C#](#help-csharp)
  * [Other](#help-other)
  
</details>

# <a name="about"></a>About this project
The gShell Api Generator project is an ambitious project written in PowerShell that will produce a PowerShell module in the PowerShell Gallery for each of the Google APIs*, automatically. I'm trying to fill in the gaps left by Google for the PowerShell community.

<sub>* As long as the API is listed in the Google Discovery API, for now.</sub>

### <a name="about-background"></a>How does it work - some background
Some facts to start off to help make sense of how it works and why.

* Google provides a C# / .Net client library for most of their APIs
  * The core authentication libraries are manually written
  * The client libraries for each API are then automatically generated via a [Python project](https://github.com/google/apis-client-generator) and are written to hook in to the core authentication libraries
  * Google provides the compiled C# libraries in [NuGet](https://www.nuget.org/profiles/google-apis-packages)
* I previously created [gShell](https://github.com/squid808/gShell), which is a manually-written project in C# that layered on top of the Google client libraries for a select few (15 I think?) Google APIs.
  * I made use of the Python project to successfully generate some of the code, but it required lots of manual touch-up

With this in mind, I attempted first to use a fork of their Python project to generate everything, but keeping up with the changes in that project was going to be a hurdle; I also have no guarantee that they'll keep using that forever. Plus, since it generates the code for all their client libraries it needed to be heavily language-agnostic which made the back-end pretty dang complex and difficult to really understand the meaning and use of everything they had going on.

Basically, trying to hijack the Python project would mean attempting to suss out what information was needed, creating crazy Django-based templates and custom code hooks, generating both their code AND my code and compiling it each time there was an update.

It didn't seem sustainable for me.

If I was going to start generating my own code completely, I knew that I didn't really need any info about the Google APIs except for what was relevant to the C# code. Logically, that means I could instead go straight to the source and get that information from the C# libraries that are already compiled via reflection. Since it's based on code from Google that has already passed their testing and has been compiled *and* it comes from a code generator which means there are patterns and standards, this gives me a reasonable guarantee that my basis is going to be as close to accurate as possible.

### <a name="about-how-it-works"></a>You still haven't said how it works though
Here's a breakdown of the major pieces:

* gShell has been stripped and rewritten to gShell.Main - a core library that handles the gShell authentication based on the Google authentication libraries
* The gShell Api Generator first gets a list of APIs from the Google Discovery API
* For each Api in this list it attempts to find the most recent compiled C# api client library in Nuget
* If the NuGet version has been updated (or is new) since the last time the generator ran, it is downloaded and the process proceeds for this Api
* The client library is scanned via reflection and relevant information is pulled out, processed and put in an object
* The object is used to generate C# code based on custom templates that are set up to interface with gShell.Main
* Additional meta files are created (xml-based help documents, wiki files) also based on that information
* The files are then compiled in to a C# library
  * If successful, the code and updated wiki are committed to their respective Git repositories
  * If successful, the compiled code and all necessary files are packaged up and pushed to the PowerShell gallery
* Once all new or updated Apis have run a [status summary page for all APIs](https://github.com/squid808/GshellAutomationTest/wiki/ModulesIndex) is generated to reflect the status of all APIs and provide an index to all Wiki files and committed to the Wiki repo.
* All commits are pushed to their respective repositories.

# <a name="status"></a>Current project status
Currently all major components are implemented into a working script, but there are plenty of bugs to iron out yet. A few pieces (like the pushing to Git and PowerShell Gallery) have been tested but are not in place for the testing workflow.

Unit tests are only just beginning.

Full progress can currently be found in the [*develop branch*](https://github.com/squid808/gShellApiGenerator/tree/develop).

# <a name="history"></a>Project history until now
The first thing to say is that, in its current form it produces relatively consistant and viable results. But, it has a long way to go.

Due to my limited and inconsistant free time to work on it and the discovery-based nature of the project, the development cycle has been much closer to rapid prototyping and live testing rather than something akin to TDD. This means the code smell is intense and refactoring is both likely and necessary.

I wish I could have planned everything out in advance, but to see over each new ledge I had to build myself higher with shakey code before I knew what next steps I could take. I decided that it would make the most sense to leave refactoring and unit tests until the very end, rather than doing so at each cycle.

I realize this isn't best practice, but if I followed best practice I'd still be planning things out rather than having a reasonably working prototype.

# <a name="help"></a>How can I help?
At this point I have proven that it can be done, and the bulk of the discovery and implementation is taken care of. While the code is a mess and at some points inconsistant, but it *does* produce viable results.

Please consider the following main goals, following standard Git etiquette, and if you think you can help please feel free to get in touch with me. I guess the trendy thing right now is to [join us in Discord](https://discord.gg/Q2vz4hJ).

### <a name="help-powershell"></a>For PowerShell coders
* Make code less smelly
  * Create reasonable comments and function details
  * Convert and condense in to a single module
  * Restructure the project in a sensible and modular way
* Create unit tests with Pester for the Api Generator
* Reconsider the back-end indexing option (currenly a json file, maybe SQLite?)
* Reconsider the approach to gathering files from NuGet
* Generate json files for non-Discovery APIs, eg Cloud Print**

### <a name="help-csharp"></a>For C# coders
* Figure out how to make this work with PowerShell core for cross-platform support
* Create unit tests for gShell.Main

### <a name="help-other"></a>For anyone
* Plan out and implement a CI solution that is compatible for this type of project

<sub>**Note that I have also already done something similar to this for previous iterations of gShell, but that's not important at the moment.</sub>