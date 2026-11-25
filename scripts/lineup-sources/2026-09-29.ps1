<#
    Week 7 (2026-09-29) lineups, transcribed from the full-week report fetched
    live from the currentscores URL. Like week 5, this report omitted
    averages and only tagged explicit "(BLIND)" fills at the per-person
    level (no sub tags at all - a few new names this week are almost
    certainly one-off subs, but since the report doesn't distinguish them
    from regulars, they're left as plain 'bowler' entries per the report's
    own classification).
#>

$teams = [ordered]@{
    "Light 'Em Up" = @(
        T 'Wes Widick' 0
        T 'Brian Birely' 0
        T 'Shaun Labay' 0
        T 'Derek Birely' 0
        T 'Jared Birely' 0
    )
    'Panetta Heating' = @(
        T 'Rocco Panetta' 0
        T 'Jeffrie Delaney' 0
        T 'Tony Panetta' 0
        T 'Gianna E Panetta' 0
        T 'Randy Wood' 0
    )
    'Busting Nuts' = @(
        T 'Audra Tafoya' 0
        T 'Dan Mehman' 0
        T 'Reid Gaines' 0
        T 'Dustin Richardson' 0
        T 'Kole Silz' 0
    )
    'Kamikaze Keglers' = @(
        T 'Zach Knight' 0
        T 'JJ Harnke' 0
        T 'Dave Eddy' 0
        T 'Spenser Hanson' 0
        T 'Jon Hanson' 0
    )
    'Wheelhouse' = @(
        T 'Wayne Gosselin' 0
        T 'Mick Coakley' 0
        T 'Phillip Gosselin' 0
        T 'Stefan Holt' 0
        T 'Ryan Holt' 0
    )
    'SHARKS' = @(
        T 'Matt Padilla' 0
        T 'Steve Gonnella' 0
        T 'Vincent Padilla' 0
        T 'Todd Sanders' 0
        T 'Mark Hoffman' 0
    )
    'THE DEN' = @(
        T 'Van Vasquez' 0
        T 'Rich Lista' 0
        T 'Kevin Sweetman' 0
        T 'James Eisenhauer' 0
        T 'Alex Gott' 0
    )
    'No Llores' = @(
        T 'Santino DeLeon' 0
        T 'Derek Gonzales' 0
        T 'Jesus Meraz' 0
        T 'Robb Vigil' 0
        T 'Eric Cummings' 0
    )
    'Multiple Scorgasms' = @(
        T 'Phoenix Chavez' 0
        T 'Bobby Torrez' 0
        T 'Frank Ramirez' 0
        T 'Jermaine Mccarter' 0
        T 'Mike Chavez' 0
    )
    'Apex Auto Glass' = @(
        T 'Tham Namvong' 0
        T 'Jerry Navasack' 0
        T 'Atreyu Sinouansai' 0
        T 'Somdeth Sinouansai' 0
        T 'John Gwynn' 0
    )
    'Mike Litzwet' = @(
        T 'John Schissler' 0
        T 'Zach Joslin' 0
        T 'Walter Hirt' 0
        T 'Derek Schissler' 0
        T 'Frank Guccione' 0
    )
    'Crippled Khaos' = @(
        T 'Mark Donner' 0
        T 'Gregory Fistell' 0
        T 'Stephanie David' 0
        T 'Stephen Sutton' 0 'blind' $null 'Stephen Sutton'
        T 'William Kondrotis' 0
    )
    'Rocky Mountain Tap & Garden' = @(
        T 'Chris Landis' 0 'blind' $null 'Chris Landis'
        T 'Doug Mclaughlin' 0
        T 'Troy Wilson' 0
        T 'Terry Conklin' 0
        T 'Max Landis' 0
    )
    'Luxury Box Sports' = @(
        T 'Aaron Chilton' 0
        T 'Jamaal Calhoun' 0
        T 'Rayvone Hackshaw' 0
        T 'Jeffrey Jones' 0
        T 'Benjie Garrison' 0
    )
    "LET'S GET IT!" = @(
        T 'Sharon Coleman' 0
        T 'Howard Moore' 0
        T 'Jermaine Brown' 0
        T 'Rick Armstrong (Showtime)' 0
        T 'Ishmael Smittie' 0
    )
    'Motiv' = @(
        T 'Katrina Suthers' 0
        T 'Julian Torres' 0
        T 'Nick Fritchell' 0
        T 'Nicholas B Todack' 0
        T 'Johnny Camacho' 0
    )
    'Buzz Roofing' = @(
        T 'Brett Elliott' 0
        T 'Galen Sisto' 0
        T 'Lu Busnardo' 0 'blind' $null 'Lu Busnardo'
        T 'Keith Kondratko' 0
        T 'Frank Busnardo' 0
    )
    'Hot XXX' = @(
        T 'Brian Farrell' 0
        T 'Aaron Levine' 0
        T 'Cameron Alcorn' 0
        T 'Tony Silva' 0
        T 'Mark Umscheid' 0
    )
    'StarDust Lounge' = @(
        T 'John Lund' 0
        T 'Cristina Gunnett' 0
        T 'Bob Burkhead' 0
        T 'Ian Pike' 0
        T 'Greg Davies Jr' 0
    )
    'Throw A Better Ball' = @(
        T 'Danika Rangel' 0
        T 'Andrew Schlehuber' 0
        T 'Adam Salinas' 0
        T 'Damion Rangel' 0
        T 'Mario Vigil' 0
    )
    'Aftermath' = @(
        T 'Nick Sandoval' 0
        T 'Jennifer Davis' 0
        T 'Eddie Lara' 0
        T 'Dion Griego' 0
        T 'Geno Lavigna' 0
    )
    'Bowlscore.com' = @(
        T 'Ted Vargas' 0
        T 'Rodwyn Lyons Sr' 0
        T 'Ed Cutshaw' 0
        T 'Lee Schwartz' 0
        T 'Adam Philp' 0
    )
    'Matrix Auto Body' = @(
        T 'Scott Bruce' 0
        T 'Richard Isaacs' 0
        T 'Dave Simpson' 0
        T 'Brandon May' 0
        T 'Larry May' 0
    )
    'Leave Your Mark Pro Shop' = @(
        T 'Marco Popovich' 0
        T 'Brenna Tripp' 0
        T 'Hailey Howard' 0
        T 'Aaron Howard' 0
        T 'Timothy Tripp' 0
    )
    'Last Minute' = @(
        T 'Erick Podwill' 0
        T 'Gabby Pineda' 0
        T 'Shawn Clements' 0
        T 'Fred Pedroza' 0 'blind' $null 'Fred Pedroza'
        T 'Dru Martin' 0
    )
    'PIN-A-TRATORS' = @(
        T 'Benjamin Morgan' 0
        T 'Greg Hydle' 0
        T 'Jayden Cary' 0
        T 'Greg Morgan' 0
        T 'Deon Fleming' 0
    )
    'Over the Line' = @(
        T 'Kelly Lawson' 0
        T 'Shawn Claussen' 0
        T 'Rey Rodriguez' 0
        T 'Noah Werner' 0
        T 'Jon Brockett' 0
    )
    'The Money Team' = @(
        T 'John Laws' 0
        T 'Bobby Hurtado' 0
        T 'Matthew Quintana' 0
        T 'Joseph Guinn' 0
        T 'Blair Watkins' 0
    )
    'Better Than Gold' = @(
        T 'Eric Phillips' 0
        T 'Chad Schneider' 0
        T 'Taryn Frenzel' 0
        T 'Craig Moravy' 0
        T 'Lee Kastberg' 0
    )
    'J. Crew' = @(
        T 'Pierre Lopez' 0
        T 'Craig Stout' 0
        T 'Robert Gift' 0
        T 'Lee Ripley' 0
        T 'Shaun Fowler' 0
    )
    'Sloppy Hookers' = @(
        T 'Rich Pennal' 0
        T 'John Crowder' 0
        T 'Robert McQuoid' 0
        T 'Adam Perski' 0
        T 'Trey Simpson' 0
    )
    'Mother Chuckers' = @(
        T 'Trey Erickson' 0
        T 'Chuck Dreux' 0
        T 'Tim Pester' 0
        T 'Bryan Keller' 0
        T 'Jordan Yancey' 0
    )
    'Lamorie Painting' = @(
        T 'Patrick Hunt' 0
        T 'Gary Losh' 0
        T 'Justin Phillips' 0
        T 'Nicholas Peterson-Pedroza (Nick Pedroza)' 0
        T 'Eric Hernlund' 0
    )
    'SASQUATCHED' = @(
        T 'Frank Torrez' 0
        T 'Blaize Walker' 0
        T 'Chris Naab' 0
        T 'Anthony Unrein IV' 0
        T 'Sam Johns' 0
    )
    'Rocky Mountain High' = @(
        T 'Bob Johnson' 0
        T 'Scott Carothers' 0
        T 'Mike Vasquez' 0
        T 'Nolan Carothers' 0
        T 'Mike Hinsley' 0
    )
    'The Bowler Depot' = @(
        T 'Anthony Allen' 0
        T 'Jo Struble' 0
        T 'Roger Wahler' 0
        T 'Adam D Sakowski' 0
        T 'Cody Vaughn' 0
    )
    'Corpse Crew' = @(
        T 'Paul Quinn' 0
        T 'Tanya Craig' 0
        T 'Randy Cleghorn' 0
        T 'Kayla Osei' 0
        T 'Josh Henshaw' 0
    )
    'Chicken Nuggies' = @(
        T 'William Reynolds' 0
        T 'Sarah Garofano' 0
        T 'Justyne Jansen' 0
        T 'Brian Douglass' 0
        T 'Dante Lundy' 0 'blind' $null 'Dante Lundy'
    )
    'Denver Vibrator' = @(
        T 'Jami May-Bruce' 0
        T 'Austin Huyser' 0
        T 'Ron Wooley' 0
        T 'Jeff Lagrange' 0
        T 'Ron Burley' 0
    )
    'Suicide Kings' = @( # renamed from "Pocket Aces" week of 2026-10-06
        T 'Greg Baldassar' 0
        T 'Aj Woodvine' 0
        T 'Brian Moss' 0
        T 'Jason Busnardo' 0
        T 'Roman Archuleta' 0
    )
}
