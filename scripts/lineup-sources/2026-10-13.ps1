<#
    Week 9 (2026-10-13) lineups, from the full-week report fetched live. The
    report's printed averages were unreliable once summarized (misaligned rows),
    so each avg here is the one that reproduces the bowler's ACTUAL week-9 handicap
    (handicap row minus scratch row; checked: all 40 team handicap totals match the report). Blind slots use (blind game + 10), which is
    the average LeaguePals blinded them at. Subs are judged by diffing against
    prior weeks' lineups; the report doesn't tag them.
#>

$teams = [ordered]@{
    'Corpse Crew' = @(
        T 'Joe Panetta' 86
        T 'Paul Quinn' 148
        T 'Tanya Craig' 161
        T 'Randy Cleghorn' 193
        T 'Josh Henshaw' 203
    )
    'SASQUATCHED' = @(
        T 'Frank Torrez' 190
        T 'Greg Wobbema' 212
        T 'Chris Naab' 210
        T 'Anthony Unrein IV' 200
        T 'Sam Johns' 205
    )
    'Denver Vibrator' = @(
        T 'Jami May-Bruce' 202
        T 'Austin Huyser' 209
        T 'Ron Wooley' 200
        T 'Jeff Lagrange' 211
        T 'Ron Burley' 216
    )
    'The Bowler Depot' = @(
        T 'Anthony Allen' 219
        T 'Jo Struble' 208
        T 'Roger Wahler' 211
        T 'Adam D Sakowski' 227
        T 'Cody Vaughn' 235
    )
    "Light 'Em Up" = @(
        T 'Brian Birely' 201
        T 'Brian Ray' 189
        T 'Shaun Labay' 205
        T 'Bobby Quick' 235 'sub' 'Jared Birely'
        T 'Derek Birely' 232
    )
    'Chicken Nuggies' = @(
        T 'William Reynolds' 203
        T 'Sarah Garofano' 163
        T 'Justyne Jansen' 206
        T 'Brian Douglass' 210
        T 'Dante Lundy' 235
    )
    'Busting Nuts' = @(
        T 'Audra Tafoya' 175
        T 'Dan Mehman' 146
        T 'Mike Read' 173
        T 'Kole Silz' 201
        T 'Dustin Richardson' 188
    )
    'Suicide Kings' = @(
        T 'Aj Woodvine' 207
        T 'Roman Archuleta' 223 'blind' $null 'Roman Archuleta'
        T 'Greg Baldassar' 201
        T 'Brian Moss' 211
        T 'Jason Busnardo' 226
    )
    'Wheelhouse' = @(
        T 'Wayne Gosselin' 153
        T 'Thomas Holt' 175
        T 'Mick Coakley' 187
        T 'Stefan Holt' 190
        T 'Phillip Gosselin' 195
    )
    'Panetta Heating' = @(
        T 'Rocco Panetta' 192
        T 'Jeffrie Delaney' 227
        T 'Tony Panetta' 172
        T 'Robert Gieck' 215
        T 'Randy Wood' 235
    )
    'THE DEN' = @(
        T 'Kortnie Moore' 85 'sub' 'Kevin Sweetman'
        T 'Van Vasquez' 170
        T 'Rich Lista' 187
        T 'Isiah Nakamura' 175 'sub' 'James Eisenhauer'
        T 'Alex Gott' 207
    )
    'Kamikaze Keglers' = @(
        T 'Zach Knight' 185
        T 'JJ Harnke' 189 'blind' $null 'JJ Harnke'
        T 'Spenser Hanson' 216
        T 'Jon Hanson' 196
        T 'Dave Eddy' 206
    )
    'Multiple Scorgasms' = @(
        T 'Jermaine Mccarter' 196
        T 'Bobby Torrez' 191
        T 'Frank Ramirez' 188
        T 'Mike Chavez' 203
        T 'Phoenix Chavez' 220
    )
    'SHARKS' = @(
        T 'Matt Padilla' 209
        T 'David Padilla' 191
        T 'Vincent Padilla' 193
        T 'Todd Sanders' 210
        T 'Mark Hoffman' 235
    )
    'Mike Litzwet' = @(
        T 'Walter Hirt' 158
        T 'Zach Joslin' 207
        T 'John Schissler' 197
        T 'Derek Schissler' 202
        T 'Ricky Schissler' 225
    )
    'No Llores' = @(
        T 'Tonya Garcia' 170
        T 'Derek Gonzales' 201
        T 'Jesus Meraz' 189
        T 'Robb Vigil' 200
        T 'Eric Cummings' 217
    )
    'Rocky Mountain Tap & Garden' = @(
        T 'Doug Mclaughlin' 203
        T 'Chris Landis' 206
        T 'Troy Wilson' 185
        T 'Terry Conklin' 196
        T 'Max Landis' 208
    )
    'Apex Auto Glass' = @(
        T 'Tham Namvong' 215
        T 'Ying Singchaichana' 213
        T 'Bounethai Novankham' 195
        T 'Somdeth Sinouansai' 222
        T 'John Gwynn' 235
    )
    "LET'S GET IT!" = @(
        T 'Sharon Coleman' 183
        T 'Robert Coleman' 191
        T 'Jermaine Brown' 212
        T 'Rick Armstrong (Showtime)' 205
        T 'Ishmael Smittie' 203
    )
    'Crippled Khaos' = @(
        T 'Mark Donner' 175
        T 'Gregory Fistell' 209
        T 'Stephanie David' 189
        T 'William Kondrotis' 209
        T 'Stephen Sutton' 225
    )
    'Luxury Box Sports' = @(
        T 'Aaron Chilton' 204 'blind' $null 'Aaron Chilton'
        T 'Jamaal Calhoun' 229
        T 'Rayvone Hackshaw' 212
        T 'Jeffrey Jones' 210
        T 'Benjie Garrison' 226
    )
    'Motiv' = @(
        T 'Katrina Suthers' 195
        T 'Julian Torres' 208
        T 'Nick Fritchell' 203
        T 'Nicholas B Todack' 201
        T 'Johnny Camacho' 210
    )
    'StarDust Lounge' = @(
        T 'Tony Fleming' 215 'sub' 'Rene Movilion'
        T 'John Lund' 205
        T 'Bob Burkhead' 203
        T 'Ian Pike' 220
        T 'Greg Davies Jr' 230
    )
    'Buzz Roofing' = @(
        T 'Brett Elliott' 207
        T 'Galen Sisto' 188
        T 'Lu Busnardo' 180
        T 'Keith Kondratko' 220
        T 'Frank Busnardo' 203
    )
    'Aftermath' = @(
        T 'Nick Sandoval' 192
        T 'Jennifer Davis' 197
        T 'Eddie Lara' 199
        T 'Dion Griego' 201
        T 'Geno Lavigna' 217
    )
    'Hot XXX' = @(
        T 'Brian Farrell' 180
        T 'Aaron Levine' 200
        T 'Cameron Alcorn' 187
        T 'Timothy Lehl' 223 'blind' $null 'Timothy Lehl'
        T 'Mark Umscheid' 235
    )
    'Matrix Auto Body' = @(
        T 'Scott Bruce' 205
        T 'Richard Isaacs' 193
        T 'Dave Simpson' 198
        T 'Brandon May' 196
        T 'Larry May' 215
    )
    'Throw A Better Ball' = @(
        T 'Damion Rangel' 212
        T 'Andrew Schlehuber' 205
        T 'Mariah Salinas' 155
        T 'Mario Vigil' 215
        T 'Adam Salinas' 209
    )
    'Last Minute' = @(
        T 'Gabby Pineda' 195
        T 'Erick Podwill' 209
        T 'Shawn Clements' 208
        T 'Fred Pedroza' 190
        T 'Dru Martin' 217
    )
    'Bowlscore.com' = @(
        T 'Rodwyn Lyons Sr' 196
        T 'Ted Vargas' 197
        T 'Lee Schwartz' 213
        T 'Adam Philp' 215
        T 'Ed Cutshaw' 216
    )
    'Over the Line' = @(
        T 'Kelly Lawson' 189
        T 'Shawn Claussen' 205
        T 'Rey Rodriguez' 179
        T 'Noah Werner' 225
        T 'Jon Brockett' 212
    )
    'Leave Your Mark Pro Shop' = @(
        T 'Marco Popovich' 225
        T 'Brenna Tripp' 198
        T 'Hailey Howard' 219
        T 'Aaron Howard' 222
        T 'Timothy Tripp' 235
    )
    'Better Than Gold' = @(
        T 'Eric Phillips' 229
        T 'Chad Schneider' 186
        T 'Taryn Frenzel' 202
        T 'Craig Moravy' 213 'blind' $null 'Craig Moravy'
        T 'Lee Kastberg' 208
    )
    'PIN-A-TRATORS' = @(
        T 'Greg Morgan' 229
        T 'Greg Hydle' 210
        T 'David Owens' 191
        T 'Benjamin Morgan' 227
        T 'Deon Fleming' 235
    )
    'Sloppy Hookers' = @(
        T 'Rich Pennal' 188
        T 'John Crowder' 172
        T 'Adam Perski' 223
        T 'Robert McQuoid' 193
        T 'Trey Simpson' 215
    )
    'The Money Team' = @(
        T 'Bobby Hurtado' 205
        T 'Devon Hilliard' 188
        T 'Matthew Quintana' 172
        T 'Joseph Guinn' 205
        T 'Blair Watkins' 205
    )
    'Lamorie Painting' = @(
        T 'Rudy Lamorie' 212
        T 'Gary Losh' 209
        T 'Patrick Hunt' 225
        T 'Nicholas Peterson-Pedroza (Nick Pedroza)' 202
        T 'Eric Hernlund' 221
    )
    'J. Crew' = @(
        T 'Pierre Lopez' 168
        T 'Corrin Ripley' 209
        T 'Craig Stout' 200
        T 'Lee Ripley' 218
        T 'Michael Ligeski' 240 'blind' $null 'Michael Ligeski'
    )
    'Rocky Mountain High' = @(
        T 'Bob Johnson' 157
        T 'Scott Carothers' 217
        T 'Mike Vasquez' 199
        T 'Nolan Carothers' 181 'blind' $null 'Nolan Carothers'
        T 'Mike Hinsley' 217
    )
    'Mother Chuckers' = @(
        T 'Erin Marchant' 208
        T 'Trey Erickson' 205
        T 'Chuck Dreux' 200
        T 'Tim Pester' 225
        T 'Bryan Keller' 215
    )
}
