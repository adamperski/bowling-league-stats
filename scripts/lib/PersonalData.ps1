# Personal data that LeaguePals includes in its public responses. This project doesn't need it and
# must never save or publish it. Dot-source this file and pass every response through
# Protect-LeagueJson before it is written to disk.
#
#   * birth dates, profile pictures, phone numbers and street addresses -> null
#   * any real email address -> removed. LeaguePals' placeholder "bowlerN@teamM" values are kept:
#     they identify no one and Build-Stats.ps1 reads the roster position from them.
#   * league "members" lists (user account ids and officer roles) -> emptied

$script:PdFieldRx = [regex]('"(birthDate|dateOfBirth|dob|avatar|phone|phoneNumber|mobile|cellPhone|address|address1|address2|street|zipCode)"(\s*:\s*)' +
                            '(?:"[^"\\]*(?:\\.[^"\\]*)*"|-?\d+(?:\.\d+)?|true|false)')
$script:PdEmailRx = [regex]'(?<![A-Za-z0-9._%+-])(?!bowler\d+@team)[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}'
# a "members" array with something in it (balancing groups find the matching closing bracket)
$script:PdMembersRx = [regex]('"members"(\s*:\s*)\[(?!\s*\])(?>"[^"\\]*(?:\\.[^"\\]*)*"|[^\[\]"]+|\[(?<d>)|\](?<-d>))*(?(d)(?!))\]')

function Protect-LeagueJson {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)
    $Text = $script:PdFieldRx.Replace($Text, '"$1"$2null')
    $Text = $script:PdEmailRx.Replace($Text, '')
    $script:PdMembersRx.Replace($Text, '"members"$1[]')
}
