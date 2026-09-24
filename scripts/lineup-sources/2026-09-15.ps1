<#
    Week 5 (2026-09-15) lineups, transcribed from the full-week report fetched
    live from the currentscores URL. This week's report format omitted
    averages entirely and didn't tag subs (only "(Blind)"), so avg is left 0
    (falls back to the live roster/current average - fine for handicap
    purposes on established bowlers) and sub/blind classification was
    determined by diffing each team's listed 5 against their known roster
    from weeks 1-4 (scripts\lineup-sources\2026-08-18.ps1 etc). Some teams
    carry a roster larger than 5 and rotate normally (not a sub situation) -
    those are left as plain 'bowler' entries. J. Crew's report had a rendering
    glitch (Pierre Lopez split across two rows); collapsed to one entry.
#>

$teams = [ordered]@{
    'Mother Chuckers' = @(
        T 'Erin Marchant' 0
        T 'Trey Erickson' 0
        T 'Chuck Dreux' 0
        T 'Tim Pester' 0
        T 'Bryan Keller' 0
    )
    'The Money Team' = @(
        T 'John Laws' 0 'blind' $null 'John Laws'
        T 'Nicole Demonte' 0
        T 'Matthew Quintana' 0
        T 'Joseph Guinn' 0
        T 'Blair Watkins' 0
    )
    'Busting Nuts' = @(
        T 'Dan Mehman' 0
        T 'Mike Read' 0 'blind' $null 'Mike Read'
        T 'Dustin Richardson' 0
        T 'Audra Tafoya' 0
        T 'Kole Silz' 0
    )
    'Lamorie Painting' = @(
        T 'Rudy Lamorie' 0
        T 'Gary Losh' 0
        T 'Patrick Hunt' 0 'sub' 'Nicholas Peterson-Pedroza (Nick Pedroza)'
        T 'Justin Phillips' 0
        T 'Eric Hernlund' 0
    )
    'Hot XXX' = @(
        T 'Brian Farrell' 0
        T 'Aaron Levine' 0
        T 'Cameron Alcorn' 0
        T 'Timothy Lehl' 0
        T 'Mark Umscheid' 0
    )
    'Panetta Heating' = @(
        T 'Rocco Panetta' 0
        T 'Jeffrie Delaney' 0
        T 'Tony Panetta' 0
        T 'Robert Gieck' 0
        T 'Randy Wood' 0
    )
    'SASQUATCHED' = @(
        T 'Frank Torrez' 0
        T 'Blaize Walker' 0
        T 'Chris Naab' 0
        T 'Anthony Unrein IV' 0
        T 'Greg Wobbema' 0
    )
    'Denver Vibrator' = @(
        T 'Jami May-Bruce' 0
        T 'Austin Huyser' 0
        T 'Ron Wooley' 0
        T 'Janet Krebs' 0
        T 'Jeff Lagrange' 0
    )
    'Better Than Gold' = @(
        T 'Eric Phillips' 0
        T 'Chad Schneider' 0
        T 'Taryn Frenzel' 0
        T 'Craig Moravy' 0
        T 'Lee Kastberg' 0
    )
    "LET'S GET IT!" = @(
        T 'Sharon Coleman' 0
        T 'Howard Moore' 0
        T 'Robert Coleman' 0
        T 'Rick Armstrong (Showtime)' 0
        T 'Jermaine Brown' 0
    )
    'Rocky Mountain High' = @(
        T 'Bob Johnson' 0
        T 'Scott Carothers' 0
        T 'Mike Vasquez' 0
        T 'Nolan Carothers' 0
        T 'Mike Hinsley' 0
    )
    'Throw A Better Ball' = @(
        T 'Damion Rangel' 0
        T 'William A Gotwald' 0
        T 'Adam Salinas' 0
        T 'Andrew Schlehuber' 0
        T 'Mario Vigil' 0
    )
    'Motiv' = @(
        T 'Katrina Suthers' 0
        T 'Julian Torres' 0
        T 'Steven Armijo' 0 'sub' 'Nick Fritchell'
        T 'Nicholas B Todack' 0
        T 'Mickel Dominique' 0 'sub' 'Johnny Camacho'
    )
    'THE DEN' = @( # renamed from "Sweetman Racing" week of 2026-09-22
        T 'Kortnie Moore' 0 'sub' 'Kevin Sweetman'
        T 'Van Vasquez' 0
        T 'Rich Lista' 0
        T 'James Eisenhauer' 0
        T 'Alex Gott' 0
    )
    'PIN-A-TRATORS' = @(
        T 'Benjamin Morgan' 0
        T 'Greg Hydle' 0
        T 'David Owens' 0
        T 'Greg Morgan' 0
        T 'Deon Fleming' 0
    )
    'Leave Your Mark Pro Shop' = @(
        T 'Marco Popovich' 0
        T 'Brenna Tripp' 0
        T 'Hailey Howard' 0 'blind' $null 'Hailey Howard'
        T 'Aaron Howard' 0
        T 'Timothy Tripp' 0
    )
    "Light 'Em Up" = @(
        T 'Wes Widick' 0
        T 'Brian Birely' 0
        T 'Shaun Labay' 0
        T 'Derek Birely' 0
        T 'Jared Birely' 0
    )
    'Wheelhouse' = @(
        T 'Wayne Gosselin' 0
        T 'Thomas Holt' 0
        T 'Mick Coakley' 0
        T 'Phillip Gosselin' 0
        T 'Stefan Holt' 0
    )
    'Apex Auto Glass' = @(
        T 'Tham Namvong' 0
        T 'Ying Singchaichana' 0
        T 'Bounethai Novankham' 0
        T 'Somdeth Sinouansai' 0
        T 'John Gwynn' 0
    )
    'The Bowler Depot' = @(
        T 'Anthony Allen' 0
        T 'Jo Struble' 0
        T 'Roger Wahler' 0
        T 'Adam D Sakowski' 0
        T 'Cody Vaughn' 0
    )
    'J. Crew' = @(
        T 'Pierre Lopez' 0
        T 'Craig Stout' 0
        T 'Robert Gift' 0
        T 'Lee Ripley' 0
        T 'Michael Ligeski' 0 'blind' $null 'Michael Ligeski'
    )
    'Luxury Box Sports' = @(
        T 'Jamaal Calhoun' 0
        T 'Aaron Chilton' 0 'blind' $null 'Aaron Chilton'
        T 'Rayvone Hackshaw' 0
        T 'Jeffrey Jones' 0
        T 'Benjie Garrison' 0
    )
    'Mike Litzwet' = @( # renamed from "Schissler's Army" week of 2026-09-22
        T 'Zach Joslin' 0
        T 'John Schissler' 0
        T 'Aaron Schissler' 0
        T 'Derek Schissler' 0
        T 'Ricky Schissler' 0
    )
    'SHARKS' = @(
        T 'Matt Padilla' 0 'blind' $null 'Matt Padilla'
        T 'Steve Gonnella' 0 'sub' 'David Padilla'
        T 'Vincent Padilla' 0
        T 'Todd Sanders' 0
        T 'Mark Hoffman' 0
    )
    'Sloppy Hookers' = @(
        T 'Rich Pennal' 0
        T 'John Crowder' 0
        T 'Robert McQuoid' 0
        T 'Adam Perski' 0
        T 'Ron Lowe' 0 'sub' 'Trey Simpson'
    )
    'Rocky Mountain Tap & Garden' = @(
        T 'Doug Mclaughlin' 0
        T 'Troy Wilson' 0
        T 'Terry Conklin' 0
        T 'Chris Landis' 0
        T 'Max Landis' 0
    )
    'Chicken Nuggies' = @(
        T 'William Reynolds' 0
        T 'Sarah Garofano' 0
        T 'Justyne Jansen' 0
        T 'Brian Douglass' 0
        T 'Dante Lundy' 0
    )
    'Pocket Aces' = @(
        T 'Aj Woodvine' 0
        T 'Greg Baldassar' 0
        T 'Brian Moss' 0
        T 'Jason Busnardo' 0
        T 'Roman Archuleta' 0
    )
    'Kamikaze Keglers' = @(
        T 'JJ Harnke' 0
        T 'Spenser Hanson' 0
        T 'Dave Eddy' 0 'blind' $null 'Dave Eddy'
        T 'Jon Hanson' 0
        T 'Brian Garramone' 0
    )
    'Last Minute' = @(
        T 'Erick Podwill' 0
        T 'Gabby Pineda' 0
        T 'Shawn Clements' 0
        T 'Fred Pedroza' 0
        T 'Dru Martin' 0
    )
    'Bowlscore.com' = @(
        T 'Ted Vargas' 0
        T 'Rodwyn Lyons Sr' 0
        T 'Ed Cutshaw' 0
        T 'Lee Schwartz' 0
        T 'Adam Philp' 0
    )
    'No Llores' = @(
        T 'Chris Imel' 0
        T 'Derek Gonzales' 0
        T 'Jesus Meraz' 0
        T 'Robb Vigil' 0
        T 'Eric Cummings' 0
    )
    'Over the Line' = @(
        T 'Kelly Lawson' 0 'blind' $null 'Kelly Lawson'
        T 'Shawn Claussen' 0
        T 'Lonnie Wenholz' 0 'sub' 'Rey Rodriguez'
        T 'Noah Werner' 0
        T 'Jon Brockett' 0
    )
    'Multiple Scorgasms' = @(
        T 'Jermaine Mccarter' 0 'blind' $null 'Jermaine Mccarter'
        T 'Bobby Torrez' 0
        T 'Frank Ramirez' 0
        T 'Phoenix Chavez' 0
        T 'Mike Chavez' 0
    )
    'Matrix Auto Body' = @(
        T 'Scott Bruce' 0
        T 'Richard Isaacs' 0
        T 'Dave Simpson' 0
        T 'Brandon May' 0
        T 'Larry May' 0
    )
    'StarDust Lounge' = @(
        T 'John Lund' 0
        T 'Rene Movilion' 0
        T 'Bob Burkhead' 0
        T 'Ian Pike' 0
        T 'Greg Davies Jr' 0
    )
    'Crippled Khaos' = @(
        T 'Mark Donner' 0
        T 'Gregory Fistell' 0
        T 'Stephanie David' 0
        T 'William Kondrotis' 0
        T 'Stephen Sutton' 0
    )
    'Aftermath' = @(
        T 'Nick Sandoval' 0
        T 'Jennifer Davis' 0
        T 'Eddie Lara' 0
        T 'Dion Griego' 0
        T 'Duane Martinac' 0 'sub' 'Geno Lavigna'
    )
    'Corpse Crew' = @(
        T 'Joe Panetta' 0
        T 'Tanya Craig' 0 'blind' $null 'Tanya Craig'
        T 'Randy Cleghorn' 0
        T 'Kayla Osei' 0
        T 'Josh Henshaw' 0 'blind' $null 'Josh Henshaw'
    )
    'Buzz Roofing' = @(
        T 'Brett Elliott' 0
        T 'Keith Kondratko' 0
        T 'Galen Sisto' 0
        T 'Ryan Modica' 0
        T 'Frank Busnardo' 0
    )
}
