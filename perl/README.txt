Once CIM is installed you can view the generated API documentation at:
http://localhost:8080/docs/api/cim_api_reference/overview.html

There are 3 services that correspond to the main tabs in CIM:
defectservice
configurationservice
administrationservice

Using defectservice as an example, the API is at:
http://localhost:8080/ws/v2/defectservice?wsdl

and the true reference i.e. the xml schema is at:
http://localhost:8080/ws/v2/defectservice?xsd=1

-----

The scripts in this repository are meant to work with the Web Services API v2
which is initially released with CIM 5.3.

In addition to the lib directory, these scripts may require other modules to be
installed.  This can be done using CPAN or the Perl Package Manager
(ActiveState on Windows) although a copy is provided in lib-thirdparty.
SOAP-Lite (0.712 or later)
Log-Log4perl

See scripts/Integration Scripts.docx for more information.

Sumio (skiyooka@coverity.com)

-----

Release Notes for Feb 8, 2011

* added more robust ClearQuest integration using temp files
* fixed bug in assign-owner-to-unassigned-cids.pl to correctly use opt_project when retrieving scm system
* fixed bug to allow empty elements in coverity_pse_config.xml
* fixed bug in export-defect-handler.pl to be less strict about external reference
* fixed Perforce.pm to use strip-path instead of strip_path
* fixed max page size for getAssignableUsers
* fixed field issue with Serializer.pm

Release Notes for Jan 19, 2011

* added TeamTrack issue tracking integration
* added Perforce SCM integration
* fixed blank-emails sent by notification scripts
* fixed bug if only a single 'system' in coverity_pse_config.xml by setting system to be a keyattr in XMLin
* fixed minor typos in documentation
* --config is optional for set-defect-severity and the email-notify scripts

Release Notes for Dec 15, 2010

* fixed export-defect-handler.pl to use proper project defaultTriageScope
* added Integration Scripts.docx
* added Integration Scripts.pdf
* added email-notify-project.pl
* added email-notify-owners.pl
* perl scripts updated to use Web API v2
* changed <strip_path> to <strip-path>


Release Notes for Nov 24, 2010

* added workaround for when user="Various" in export-defect-handler.pl
* added workaround for %url% in export-defect-handler.pl
* fixed unix/windows eol issue in set-defect-severity.pl
* fixed incorrect get_owner() call in assign-owner-to-unassigned-cids.pl
* fixed bug where a single <id> tag within <systems> mapping broke
* fixed bug in email notification when email address is empty
* fixed bug to allow non-numeric external references in export-defect-handler.pl
* added clause to log.conf to allow log4Perl output to go to stdout instead of stderr
* added --dry-run to assign-owner-to-unassigned-cids.pl
* added exportTriage.py and importTriage.py which allows the transfer of basic triage information from 4.5/5.x to 5.x streams
* added queryDefectsByPath.py and updateDefectsByPath.py which are a work-around for bulk-triage by filepath regexp match
* added test-scm-plugin.pl to aid with debugging/creation of SCM plugins
* added SCM/ClearCase.pm plugin
* added SCM/CVS.pm plugin
* added SCM/Accurev.pm plugin
* added several third party perl modules
* added IssueTracking/ClearQuest.pm and create_cq_ticket.pl
* added IssueTracking/Jira.pm


Release Notes for Aug 24, 2010

* refactored coverity_pse_config.xml to use a project/stream to system mapping scheme with fall-through matching (like components) that use regexps.
* rewrote Config.pm to use the new scheme and provide some enscapulation.
* set-defect-severity.pl and assign-owners-to-unassigned-cids.pl no longer read coverity_pse_config.xml by default.  It now must be explicitly specified.
* instantiate an SCM plugin directly from assign-owner-to-unassigned-cids.pl.  A bit messier but by removing all the inner wiring (SCM.pm, Plugin.pm) it makes things much easier to debug.
* flattened out the IssueTracking and SCM plugin hierarchy to simplify debugging
* refactored Coverity modules to use log4Perl instead of the home-grown Coverity::Logger
* removed some unused/obsolete Coverity modules
* documented the main scripts using Perl POD.  Pass --help to invoke.
* refactored Subversion.pm to use log4Perl and Command.pm directly
* removed the Utils/Command.pm, kept the one in Coverity::Command.
* removed lib-thirdparty
* moved Coverity-WS to lib directory so that scripts will run as is from a fresh pull (push @INC, '../lib').  This currently breaks the packaging of the Coverity-WS module.  We can fix that later.
* Service.pm uses host instead of remote
* added some severities to the checker-severity-cs.xml and checker-severity-java.xml

