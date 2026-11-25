<#
    Week 8 (2026-10-06) lineups, transcribed from the full-week report fetched
    live from the currentscores URL. This report printed each bowler's average
    ("Reg"/"BLIND"/"INCOMPLETE" tags), so avgs are real and handicaps can be
    trusted. Sub classification was done by diffing against each team's
    standings roster (the report itself doesn't tag subs).
#>

$teams = [ordered]@{
    'Chicken Nuggies' = @(
        T 'William Reynolds' 207
        T 'Justyne Jansen' 194 'blind' $null 'Justyne Jansen'
        T 'Brian Douglass' 210
        T 'Brian Garofano' 211
        T 'Dante Lundy' 241
    )
    'Denver Vibrator' = @(
        T 'Jami May-Bruce' 198
        T 'Austin Huyser' 211
        T 'Ron Wooley' 203
        T 'Jeff Lagrange' 210
        T 'Ron Burley' 223
    )
    'Suicide Kings' = @(
        T 'Aj Woodvine' 207
        T 'Greg Baldassar' 196
        T 'Brian Moss' 211
        T 'Jason Busnardo' 223
        T 'Roman Archuleta' 223
    )
    "Light 'Em Up" = @(
        T 'Brian Birely' 201
        T 'Wes Widick' 192
        T 'Shaun Labay' 203
        T 'Derek Birely' 229
        T 'Jared Birely' 235
    )
    'Panetta Heating' = @(
        T 'Rocco Panetta' 192
        T 'Jeffrie Delaney' 226
        T 'Tony Panetta' 170
        T 'Robert Gieck' 222
        T 'Randy Wood' 241
    )
    'Busting Nuts' = @(
        T 'Audra Tafoya' 173
        T 'Dan Mehman' 145
        T 'Reid Gaines' 199
        T 'Kole Silz' 196
        T 'Dustin Richardson' 185
    )
    'Kamikaze Keglers' = @(
        T 'Dave Eddy' 206
        T 'JJ Harnke' 187
        T 'Spenser Hanson' 216 'blind' $null 'Spenser Hanson'
        T 'Jon Hanson' 196
        T 'Brian Garramone' 213
    )
    'Wheelhouse' = @(
        T 'Wayne Gosselin' 155
        T 'Thomas Holt' 175
        T 'Mick Coakley' 187
        T 'Phillip Gosselin' 195
        T 'Ryan Holt' 213
    )
    'SHARKS' = @(
        T 'Mark Hoffman' 237 'blind' $null 'Mark Hoffman'
        T 'David Padilla' 191
        T 'Vincent Padilla' 191
        T 'Todd Sanders' 213
        T 'Matt Padilla' 209
    )
    'THE DEN' = @(
        T 'Van Vasquez' 169
        T 'Rich Lista' 187
        T 'Isiah Nakamura' 175 'sub' 'Kevin Sweetman'
        T 'James Eisenhauer' 177
        T 'Alex Gott' 207
    )
    'No Llores' = @(
        T 'Chris Imel' 205
        T 'Derek Gonzales' 201
        T 'Jesus Meraz' 189
        T 'Robb Vigil' 198
        T 'Eric Cummings' 219
    )
    'Multiple Scorgasms' = @(
        T 'Jermaine Mccarter' 187
        T 'Bobby Torrez' 187
        T 'Frank Ramirez' 187
        T 'Mike Chavez' 203
        T 'Phoenix Chavez' 221
    )
    'Apex Auto Glass' = @(
        T 'Ying Singchaichana' 207
        T 'Jerry Navasack' 171
        T 'Atreyu Sinouansai' 201
        T 'Bounethai Novankham' 197
        T 'Somdeth Sinouansai' 225
    )
    'Mike Litzwet' = @(
        T 'John Schissler' 200
        T 'Ricky Schissler' 221
        T 'Derek Schissler' 201
        T 'Aaron Schissler' 204
        T 'Frank Guccione' 231
    )
    'Crippled Khaos' = @(
        T 'Mark Donner' 174
        T 'Gregory Fistell' 210
        T 'Stephanie David' 185
        T 'William Kondrotis' 203
        T 'Stephen Sutton' 218
    )
    'Rocky Mountain Tap & Garden' = @(
        T 'Doug Mclaughlin' 202
        T 'Chris Landis' 208
        T 'Troy Wilson' 185
        T 'Terry Conklin' 193
        T 'Max Landis' 211
    )
    'Luxury Box Sports' = @(
        T 'Jeffrey Jones' 211
        T 'Rayvone Hackshaw' 209
        T 'Aaron Chilton' 204 'blind' $null 'Aaron Chilton'
        T 'Jamaal Calhoun' 229
        T 'Benjie Garrison' 227
    )
    "LET'S GET IT!" = @(
        T 'Robert Coleman' 194
        T 'Sharon Coleman' 183
        T 'Jermaine Brown' 212 'blind' $null 'Jermaine Brown'
        T 'Rick Armstrong (Showtime)' 204
        T 'Ishmael Smittie' 206
    )
    'Motiv' = @(
        T 'Katrina Suthers' 197
        T 'Julian Torres' 205
        T 'Nick Fritchell' 207
        T 'Nicholas B Todack' 206
        T 'Johnny Camacho' 210
    )
    'Buzz Roofing' = @(
        T 'Brett Elliott' 208
        T 'Galen Sisto' 185
        T 'Lu Busnardo' 183
        T 'Keith Kondratko' 219
        T 'Frank Busnardo' 203
    )
    'Hot XXX' = @(
        T 'Brian Farrell' 179
        T 'Aaron Levine' 199
        T 'Cameron Alcorn' 186
        T 'Timothy Lehl' 227
        T 'Mark Umscheid' 241
    )
    'StarDust Lounge' = @(
        T 'John Lund' 203
        T 'Rene Movilion' 194
        T 'Bob Burkhead' 201
        T 'Ian Pike' 219
        T 'Greg Davies Jr' 230
    )
    'Throw A Better Ball' = @(
        T 'Damion Rangel' 209
        T 'Andrew Schlehuber' 207
        T 'William A Gotwald' 198
        T 'Mario Vigil' 212
        T 'Adam Salinas' 210
    )
    'Aftermath' = @(
        T 'Nick Sandoval' 192
        T 'Jennifer Davis' 198
        T 'Eddie Lara' 200
        T 'Dion Griego' 203
        T 'Geno Lavigna' 215
    )
    'Bowlscore.com' = @(
        T 'Ted Vargas' 191
        T 'Rodwyn Lyons Sr' 196
        T 'Ed Cutshaw' 212
        T 'Lee Schwartz' 213
        T 'Adam Philp' 217
    )
    'Matrix Auto Body' = @(
        T 'Scott Bruce' 203
        T 'Richard Isaacs' 194
        T 'Dave Simpson' 196
        T 'Brandon May' 195
        T 'Larry May' 213
    )
    'Leave Your Mark Pro Shop' = @(
        T 'Marco Popovich' 225
        T 'Brenna Tripp' 198
        T 'Hailey Howard' 219 'blind' $null 'Hailey Howard'
        T 'Aaron Howard' 220
        T 'Timothy Tripp' 235
    )
    'Last Minute' = @(
        T 'Gabby Pineda' 193
        T 'Dru Martin' 216
        T 'Laszlo Soos' 197
        T 'Fred Pedroza' 190
        T 'Shawn Clements' 200
    )
    'PIN-A-TRATORS' = @(
        T 'Greg Morgan' 229
        T 'Greg Hydle' 209
        T 'David Owens' 191
        T 'Benjamin Morgan' 231
        T 'Deon Fleming' 237
    )
    'Over the Line' = @(
        T 'Kelly Lawson' 189
        T 'Shawn Claussen' 205
        T 'Rey Rodriguez' 179
        T 'Lonnie Wenholz' 210
        T 'Noah Werner' 228
    )
    'The Money Team' = @(
        T 'John Laws' 209
        T 'Bobby Hurtado' 203
        T 'Matthew Quintana' 171
        T 'Joseph Guinn' 207
        T 'Blair Watkins' 202
    )
    'Better Than Gold' = @(
        T 'Eric Phillips' 227
        T 'Chad Schneider' 185
        T 'Taryn Frenzel' 204
        T 'Mick Phillips' 194 'sub' 'Craig Moravy'
        T 'Lee Kastberg' 208
    )
    'J. Crew' = @(
        T 'Michael Ligeski' 240 'blind' $null 'Michael Ligeski'
        T 'Craig Stout' 200 'blind' $null 'Craig Stout'
        T 'Robert Gift' 209
        T 'Shaun Fowler' 206
        T 'Lee Ripley' 216
    )
    'Sloppy Hookers' = @(
        T 'Rich Pennal' 189
        T 'John Crowder' 171
        T 'Robert McQuoid' 193
        T 'Adam Perski' 221
        T 'Trey Simpson' 216
    )
    'Mother Chuckers' = @(
        T 'Erin Marchant' 199
        T 'Trey Erickson' 205
        T 'Chuck Dreux' 196
        T 'Tim Pester' 220
        T 'Bryan Keller' 217
    )
    'Lamorie Painting' = @(
        T 'Rudy Lamorie' 212
        T 'Gary Losh' 208
        T 'Nicholas Peterson-Pedroza (Nick Pedroza)' 202 'blind' $null 'Nicholas Peterson-Pedroza (Nick Pedroza)'
        T 'Patrick Hunt' 215 'sub' 'Eric Hernlund'
        T 'Justin Phillips' 217
    )
    'SASQUATCHED' = @(
        T 'Frank Torrez' 195
        T 'Greg Wobbema' 208
        T 'Chris Naab' 210
        T 'Anthony Unrein IV' 202
        T 'Sam Johns' 206
    )
    'Rocky Mountain High' = @(
        T 'Bob Johnson' 156
        T 'Scott Carothers' 219
        T 'Nick Lasorsa' 194 'sub' 'Mike Vasquez'
        T 'Nolan Carothers' 182
        T 'Mike Hinsley' 221
    )
    'The Bowler Depot' = @(
        T 'Anthony Allen' 220
        T 'Jo Struble' 208
        T 'Audrey Johnson' 165 'sub' 'Roger Wahler'
        T 'Adam D Sakowski' 229
        T 'Cody Vaughn' 238
    )
    'Corpse Crew' = @(
        T 'Joe Panetta' 87
        T 'Kayla Osei' 190
        T 'Paul Quinn' 169
        T 'Randy Cleghorn' 195
        T 'Josh Henshaw' 205
    )
}
