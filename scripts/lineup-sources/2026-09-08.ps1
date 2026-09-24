<#
    Week 4 (2026-09-08) lineups, transcribed from the full-week report PDF
    the user printed and attached (20 matchups / 40 teams). Run via:

        .\scripts\Import-WeekReport.ps1 -Date 2026-09-08 `
            -DataFile scripts\lineup-sources\2026-09-08.ps1 `
            -Source "Full week-4 report PDF (printed by user, all 20 matchups), 2026-09-15"

    T() is provided by Import-WeekReport.ps1 (dot-sourced into its scope).
#>

# teamName -> ordered 5 entries (pos 1..5 = array order)
$teams = [ordered]@{
    'Wheelhouse' = @(
        T 'Wayne Gosselin' 153
        T 'Thomas Holt' 166 'sub' 'Stefan Holt'
        T 'Mick Coakley' 179
        T 'Phillip Gosselin' 204
        T 'Ryan Holt' 205
    )
    'Apex Auto Glass' = @(
        T 'Tham Namvong' 217
        T 'Jerry Navasack' 157 'sub' 'Ying Singchaichana'
        T 'Bounethai Novankham' 198
        T 'Somdeth Sinouansai' 214
        T 'John Gwynn' 237
    )
    'THE DEN' = @( # renamed from "Sweetman Racing" week of 2026-09-22
        T 'Kortnie Moore' 85 'sub' 'Kevin Sweetman'
        T 'Van Vasquez' 174
        T 'Isiah Nakamura' 175 'sub' 'James Eisenhauer'
        T 'Alex Gott' 195
        T 'Rich Lista' 197 'blind' $null 'Rich Lista'
    )
    'Crippled Khaos' = @(
        T 'Mark Donner' 184
        T 'Gregory Fistell' 202
        T 'Stephanie David' 193
        T 'Tim Yost' 187 'sub' 'Stephen Sutton'
        T 'William Kondrotis' 207
    )
    'Multiple Scorgasms' = @(
        T 'Phoenix Chavez' 215
        T 'Jermaine Mccarter' 187 'sub' 'Orlando Garcia'
        T 'Frank Ramirez' 193 'sub' 'Antonio Garcia'
        T 'Bobby Torrez' 194
        T 'Mike Chavez' 208
    )
    'Luxury Box Sports' = @(
        T 'Jamaal Calhoun' 213
        T 'Aaron Chilton' 214
        T 'Rayvone Hackshaw' 205
        T 'Jeffrey Jones' 214
        T 'Benjie Garrison' 223
    )
    'Mike Litzwet' = @( # renamed from "Schissler's Army" week of 2026-09-22
        T 'Zach Joslin' 202
        T 'John Schissler' 191
        T 'Aaron Schissler' 203
        T 'Derek Schissler' 210
        T 'Ricky Schissler' 222
    )
    "LET'S GET IT!" = @(
        T 'Sharon Coleman' 176
        T 'Howard Moore' 194
        T 'Jermaine Brown' 204
        T 'Rick Armstrong (Showtime)' 204
        T 'Ishmael Smittie' 197
    )
    'Rocky Mountain Tap & Garden' = @(
        T 'Doug Mclaughlin' 196
        T 'Chris Landis' 215
        T 'Troy Wilson' 195
        T 'Terry Conklin' 201
        T 'Max Landis' 199
    )
    'Motiv' = @(
        T 'Katrina Suthers' 193
        T 'Julian Torres' 196
        T 'Nick Fritchell' 206
        T 'Nicholas B Todack' 211
        T 'Johnny Camacho' 215
    )
    'Hot XXX' = @(
        T 'Brian Farrell' 168
        T 'Aaron Levine' 198
        T 'Cameron Alcorn' 182
        T 'Timothy Lehl' 212
        T 'Mark Umscheid' 226
    )
    'Throw A Better Ball' = @(
        T 'Damion Rangel' 199
        T 'William A Gotwald' 208
        T 'Adam Salinas' 196
        T 'Andrew Schlehuber' 207
        T 'Mario Vigil' 213
    )
    'Buzz Roofing' = @(
        T 'Brett Elliott' 205
        T 'Galen Sisto' 193
        T 'Lu Busnardo' 189
        T 'Keith Kondratko' 207
        T 'Frank Busnardo' 213
    )
    'Bowlscore.com' = @(
        T 'Angela Wolfe' 192 'sub' 'Ed Cutshaw'
        T 'Rodwyn Lyons Sr' 206
        T 'Ted Vargas' 200
        T 'Lee Schwartz' 211
        T 'Adam Philp' 215
    )
    'StarDust Lounge' = @(
        T 'John Lund' 206
        T 'Cristina Gunnett' 193 'sub' 'Rene Movilion'
        T 'Bob Burkhead' 207
        T 'Ian Pike' 220
        T 'Greg Davies Jr' 222
    )
    'Leave Your Mark Pro Shop' = @(
        T 'Marco Popovich' 226
        T 'Brenna Tripp' 208
        T 'Hailey Howard' 202
        T 'Aaron Howard' 221
        T 'Timothy Tripp' 231
    )
    'Aftermath' = @(
        T 'Nick Sandoval' 201
        T 'Jennifer Davis' 198
        T 'Eddie Lara' 203
        T 'Dion Griego' 206
        T 'Geno Lavigna' 215
    )
    'PIN-A-TRATORS' = @(
        T 'Benjamin Morgan' 222
        T 'Greg Hydle' 203
        T 'Jayden Cary' 205 'sub' 'David Owens'
        T 'Greg Morgan' 223
        T 'Deon Fleming' 225
    )
    'Matrix Auto Body' = @(
        T 'Scott Bruce' 204 'blind' $null 'Scott Bruce'
        T 'Richard Isaacs' 196
        T 'Dave Simpson' 205
        T 'Brandon May' 201
        T 'Larry May' 212
    )
    'The Money Team' = @(
        T 'John Laws' 211
        T 'Bobby Hurtado' 199
        T 'Matthew Quintana' 172
        T 'Joseph Guinn' 206
        T 'Blair Watkins' 202
    )
    'Last Minute' = @(
        T 'Erick Podwill' 213
        T 'Shawn Clements' 206 'sub' 'Fred Pedroza'
        T 'Laszlo Soos' 197 'sub' 'Joshua Blair'
        T 'Gabby Pineda' 200
        T 'Dru Martin' 205
    )
    'J. Crew' = @(
        T 'Pierre Lopez' 177
        T 'Craig Stout' 207
        T 'Robert Gift' 210
        T 'Lee Ripley' 217 'blind' $null 'Lee Ripley'
        T 'Michael Ligeski' 221
    )
    'Over the Line' = @(
        T 'Kelly Lawson' 199
        T 'Anthony Aragon' 212 'sub' 'Jon Brockett'
        T 'Rey Rodriguez' 189
        T 'Shawn Claussen' 215
        T 'Noah Werner' 218
    )
    'Mother Chuckers' = @( # renamed from "Pocket Pounders" sometime after week 4; Build-Stats.ps1 keys lineup files by CURRENT team name
        T 'Erin Marchant' 203 'sub' 'Jordan Yancey'
        T 'Trey Erickson' 190
        T 'Chuck Dreux' 193
        T 'Tim Pester' 220
        T 'Bryan Keller' 214
    )
    'Better Than Gold' = @(
        T 'Eric Phillips' 212
        T 'Chad Schneider' 189
        T 'Taryn Frenzel' 204
        T 'Craig Moravy' 212
        T 'Lee Kastberg' 218
    )
    'SASQUATCHED' = @(
        T 'Greg Wobbema' 217
        T 'Blaize Walker' 207
        T 'Chris Naab' 202
        T 'Anthony Unrein IV' 210
        T 'Sam Johns' 203
    )
    'Sloppy Hookers' = @(
        T 'Rich Pennal' 187
        T 'John Crowder' 166
        T 'Robert McQuoid' 203
        T 'Adam Perski' 218
        T 'Trey Simpson' 199
    )
    'The Bowler Depot' = @(
        T 'Jo Struble' 210
        T 'Audrey Johnson' 165 'sub' 'Anthony Allen'
        T 'Roger Wahler' 209
        T 'Adam D Sakowski' 217
        T 'Cody Vaughn' 223
    )
    'Lamorie Painting' = @(
        T 'Rudy Lamorie' 205
        T 'Gary Losh' 190
        T 'Patrick Hunt' 215 'sub' 'Nick Pedroza'
        T 'Justin Phillips' 208
        T 'Eric Hernlund' 217
    )
    'Chicken Nuggies' = @(
        T 'William Reynolds' 209
        T 'Sarah Garofano' 173
        T 'Justyne Jansen' 202
        T 'Brian Douglass' 220
        T 'Dante Lundy' 239 'sub' 'Isabel Ping'
    )
    'Rocky Mountain High' = @(
        T 'Bob Johnson' 166
        T 'Scott Carothers' 208
        T 'Mike Vasquez' 188
        T 'Nolan Carothers' 176
        T 'Mike Hinsley' 216
    )
    'Pocket Aces' = @(
        T 'Aj Woodvine' 217
        T 'Shawn Lutz' 146 'sub' 'Greg Baldassar'
        T 'Brian Moss' 211
        T 'Jason Busnardo' 223
        T 'Roman Archuleta' 233
    )
    'Corpse Crew' = @(
        T 'Joe Panetta' 82 'sub' 'Paul Quinn'
        T 'Kayla Osei' 185 'blind' $null 'Kayla Osei'
        T 'Randy Cleghorn' 189
        T 'Tanya Craig' 171
        T 'Josh Henshaw' 197
    )
    'Panetta Heating' = @(
        T 'Rocco Panetta' 202
        T 'Jeffrie Delaney' 223
        T 'Tony Panetta' 163
        T 'Robert Gieck' 222
        T 'Randy Wood' 238
    )
    'Denver Vibrator' = @(
        T 'Janet Krebs' 178 'sub' 'Jami May-Bruce'
        T 'Austin Huyser' 202
        T 'Ron Wooley' 203
        T 'Jeff Lagrange' 208
        T 'Ron Burley' 221
    )
    'Kamikaze Keglers' = @(
        T 'Dave Eddy' 212 'sub' 'Zach Knight'
        T 'JJ Harnke' 187
        T 'Spenser Hanson' 204
        T 'Jon Hanson' 200
        T 'Brian Garramone' 218
    )
    "Light 'Em Up" = @(
        T 'Bobby Quick' 234 'sub' 'Shaun Labay'
        T 'Brian Birely' 202
        T 'Wes Widick' 199
        T 'Derek Birely' 221
        T 'Jared Birely' 233
    )
    'SHARKS' = @(
        T 'Matt Padilla' 219
        T 'David Padilla' 201
        T 'Vincent Padilla' 195
        T 'Todd Sanders' 212
        T 'Mark Hoffman' 218
    )
    'Busting Nuts' = @(
        T 'Audra Tafoya' 166
        T 'Dan Mehman' 141
        T 'Mike Read' 178
        T 'Dustin Richardson' 183
        T 'Kole Silz' 155
    )
    'No Llores' = @(
        T 'Tonya Garcia' 170
        T 'Robb Vigil' 199
        T 'Jesus Meraz' 199 'blind' $null 'Jesus Meraz'
        T 'Chris Imel' 204 'sub' 'Eric Cummings'
        T 'Santino DeLeon' 162 'sub' 'Derek Gonzales'
    )
}
