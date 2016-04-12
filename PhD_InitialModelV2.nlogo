extensions [nw table CSV cf time]
; cf:an extension for "case" functionality https://github.com/qiemem/ControlFlowExtension



breed [waypoints waypoint]
breed [nodes node]
breed [LocResidentials LocResidential]
breed [people person]
breed [LocWorks LocWork]
breed [Locshops Locshop]
breed [Locschools Locschool]
breed [gpsdevices gpsdevice]                ;agents that are capable of collecting accurate gps data
breed [mobiletowers mobiletower]            ;mobile tower agents that are capable of collecting mobile phone data

globals [
  residential   ;; agentset containing the patches that are residential buildings
  shopping      ;; agentset containing the patches that are shopping landuse
  workplace     ;; agentset containing the patches that are workplace buildings
  school        ;; agentset containing the patches that are school buildings
  cur_time      ;; give each tick a time so that other features can be extracted

]

waypoints-own [

]

LocResidentials-own [

]

LocWorks-own[

]

Locshops-own[

]

Locschools-own[

]


links-own [
  street-length
]


mobiletowers-own [
  ;locxcor
  ;locycor
  ;dates
  ;times
  datarecords
  radius
  zone
]


gpsdevices-own [
]


people-own [
  IDnum
  schedule
  homecorxy
  counterMobile                    ;for the mobile tower agents to identify the people agents. they have different id numbers
  ;  workstarts
  ;  workinghours
  workplacecorxy
  shopplacecorxy
  schoolcorxy
  currentlocation                  ;current location; values: home, work, shop, school, enroute
  distances-to-other-waypoint      ;save the distance to destination
  path                             ;save the shortest path to be travelled (link pairs)

  list-waypointsall                ;save the list of waypoints (lists)
  waypoint-all                     ;save the waypoints (turtles)
  speedcar                         ;save speed of moving (car)
  WorkID                           ;save work location ID nnumber (ID for the turtle)
  HomeID                           ;save house location ID nnumber (ID for the turtle)
  ShopID                           ;save shopping location ID nnumber (ID for the turtle)
  SchoolID                         ;save school location ID nuumber (ID for the turtle)
  endofroute?                      ;reached destination?
  remainingdist                    ;distance remaining to the next node
  nextwaypoint                     ;next way point for travlling
  dummy                            ;a counter which is used during the process
  zone                             ;current zone: 1: residential; 2:work; 3:shop; 4:school

]

;*********SETUP*************

to setup
  clear-all
  random-seed 5
  set-default-shape nodes "dot"
  set-default-shape waypoints "dot"
  set-default-shape LocResidentials "house"
  set-default-shape LocWorks "house"
  set-default-shape Locshops "house"
  set-default-shape Locschools "house"
  set-default-shape mobiletowers "star"
  ;set-default-shape cars "car"

  ;;setup the landuse
  setup-landuse

  ;roadnetwork
  setup-roadnetwork

  ;initiate population
  setup-population

  ;connect place agents with road networks
  setup-connectors

  ;setup mobile phone towers
  if mobiletowerdata? [
    setup-mobiletowers
  ]

  ;input/output initialisation
  setup-fileIO

  ; set a starting time
  set cur_time time:create "2016/01/01 00:00"

  reset-ticks
end


to setup-landuse
  ;setup landuse based on different colors

  set workplace patches with
    [pycor >= 0 and pxcor < 0]
  ask workplace [ set pcolor 25 ]

  set residential patches with
    [pycor <= 0 and pxcor >= 0]
  ask residential [ set pcolor 15 ]

  set shopping patches with
    [pycor > 0 and pxcor >= 0]
  ask shopping [ set pcolor 35 ]

  set school patches with
    [pycor < 0 and pxcor < 0]
  ask school [ set pcolor 45 ]
end

to setup-roadnetwork
  ;; to setup the number of rows and columns

  ;create nodes based on the grid size defined
  ask patches with [abs pxcor < (grid-size / 2) and abs pycor < (grid-size / 2)][
    sprout-nodes 1 [ set color blue]
  ]

  ; create links between each nodes
  ask nodes [
    if Show_Names_Nodes? = True [
      ifelse label = ""
        [set label (word who " ")]
        [set label ""]
    ]
    let neighbor-nodes turtle-set [turtles-here] of neighbors4
    create-links-with neighbor-nodes [
      set street-length random 10 + 1 ;;random link length, excluding 0
      set color black
      set thickness 0.1
    ]
  ]

  ;; spread the nodes according to the size of the window
  ask nodes [
    setxy (xcor * (max-pxcor ) / floor ((grid-size / 2 )))
      (ycor * (max-pycor ) / floor ((grid-size / 2 )))
  ]

end


to setup-population

  ;workplacecorxy

  let workxcor []
  let workycor []
  let temp []
  let tempnum []
  ;let home_IDlocation []
  let i 0
  let k 0
  set-default-shape people "person"

  while [i < nb-people] [
    ask one-of residential [
      sprout-people 1 [
        set IDnum who
        set tempnum who
        set counterMobile k
        set color red
        set size 1
        set speedcar car-speed
        set homecorxy list (pxcor) (pycor)
        set currentlocation "home"
        set endofroute? true
        set zone 1
        ;set workstarts 480 ; 8am in the morning
        ;set workinghours 540 ;working 9hrs a day
        ;choose a random place in the business area as the working place
        ask one-of workplace [
          set workxcor pxcor
          set workycor pycor
        ]
        set workplacecorxy list workxcor workycor

        ;choose the shopping location
        ask one-of shopping [
          set workxcor pxcor
          set workycor pycor
        ]
        set shopplacecorxy list workxcor workycor

        ;choose the school
        ask one-of school [
          set workxcor pxcor
          set workycor pycor
        ]
        set schoolcorxy list workxcor workycor

        set list-waypointsall ""
        set nextwaypoint ""
        set dummy 0

        ;set activity schedules
        set schedule setup_activity_schedule

        ;print workplacecorxy
        ;set home_IDlocation list  home_location

        ;print list([xcor] [ycor])
        ;print home_location
      ]
      set k k + 1
    ]

    ; create destination agents for works
    create-LocWorks 1 [
      ;print [tempnum] of people
      setxy (item 0 [workplacecorxy] of turtle tempnum) (item 1 [workplacecorxy] of turtle tempnum)
      set temp who
      set color red
      ;print xcor
      ;print ycor
      hide-turtle
      set size 1
      ask turtle (tempnum) [ set WorkID temp]
    ]

    ; create destination agents for houses (residential)
    create-LocResidentials 1 [
      ;print [tempnum] of people
      setxy (item 0 [homecorxy] of turtle tempnum) (item 1 [homecorxy] of turtle tempnum)
      set temp who
      set color red
      ;print xcor
      ;print ycor
      show-turtle
      set size 1
      ask turtle (tempnum) [ set HomeID temp]
    ]

    ; create destination agents for shoppings (shops)
    create-Locshops 1 [
      ;print [tempnum] of people
      setxy (item 0 [shopplacecorxy] of turtle tempnum) (item 1 [shopplacecorxy] of turtle tempnum)
      set temp who
      set color red
      ;print xcor
      ;print ycor
      hide-turtle
      set size 1
      ask turtle (tempnum) [ set ShopID temp]
    ]

    ; create destination agents for school (school)
    create-Locschools 1 [
      ;print [tempnum] of people
      setxy (item 0 [schoolcorxy] of turtle tempnum) (item 1 [schoolcorxy] of turtle tempnum)
      set temp who
      set color red
      ;print xcor
      ;print ycor
      hide-turtle
      set size 1
      ask turtle (tempnum) [ set SchoolID temp]
    ]

    set i i + 1
    set temp []
  ]
  ;  set home_location lput [xcor] of

end


to-report setup_activity_schedule
  let data []
  let dict table:make
  set data csv:from-file "ActivitySchedule.csv"
  foreach data [table:put dict item 0 ? item 1 ?]
  ;print table:get dict 1
  ;Print table:get dict 600
  report dict
  ;[print item 0 ?];
end



to setup-connectors  ;a:origin/destination  b:coordinates
                     ; create origin and destination for the movements
                     ;let i sort people
                     ;create-waypoints nb-people
  call_connectors LocResidentials nodes
  call_connectors LocWorks nodes
  call_connectors Locshops nodes
  call_connectors Locschools nodes

end

to call_connectors [fromagent toagent]
  foreach sort fromagent [
    ask ? [
      ;setxy random-xcor random-ycor
      ;set color red
      if Show_Names_people? = True [
        ifelse label = ""
          [set label (word who " ")]
          [set label ""]
      ]
      ; find the nearest node and connect to it
      let closest-node min-one-of toagent [distance myself]
      create-link-with closest-node [
        set street-length 0
        set thickness 0.1
        set color black
        hide-link]

    ]
  ]

end

to hat-mobiletowers [zones]
  let topleftx []
  let toplefty []
  let bottomrightx []
  let bottomrighty []
  let towerx []
  let towery []
  let distx []
  let disty []

  ; get range of the zone
  set topleftx min [pxcor] of zones
  set toplefty max [pycor] of zones
  set bottomrightx max [pxcor] of zones
  set bottomrighty min [pycor] of zones

  ; now calculate middle point of the zone
  set towerx (topleftx + bottomrightx) / 2
  set towery (toplefty + bottomrighty) / 2

  set distx abs towerx
  set disty abs towery

  create-mobiletowers 1 [
    setxy towerx towery
    set color blue
    set radius min list distx disty
      ]

end

to setup-mobiletowers

  let mt_gridsize []
  let mtradius []
  let hordistance []
  let datatable table:make      ;if make table is here then all tower will share one table - this way naturally all data is collected.

  ; here we choose the middle of a patch to hatch a mobile tower

  ;workplace
  ;min [pxcor] of workplace
  ;min [pycor] of workplace
  hat-mobiletowers residential
  hat-mobiletowers workplace
  hat-mobiletowers shopping
  hat-mobiletowers school

  ;set hordistance max-pxcor - min-pxcor
  ;;currently all mobile towers have the same cover range
  ;set mtradius hordistance / grid-size * grids_covered_vector / 2
  ;set mt_gridsize ceiling (grid-size / grids_covered_vector) ;calculate the number of horizonal mt to be made

  ; generate mobiletower agents
  ;ask patches with [abs pxcor <= (mt_gridsize / 2) and abs pycor <= (mt_gridsize / 2)][
  ;  sprout-mobiletowers 1 [
  ;    set color brown
  ;    set size 2]
  ;]

  ;; spread the mobiletowers according to the size of the window
  ask mobiletowers [
  ;  setxy (xcor * (max-pxcor) / (mt_gridsize / 2 ))
  ;    (ycor * (max-pycor) / (mt_gridsize / 2 ))
    ;let datatable table:make     ;if make table is here then each tower will have their own table.
    set datarecords datatable
    ;set locxcor xcor
    ;set locycor ycor

    ;set radius mtradius
    set zone [pcolor] of patch-here
  ]
end

to setup-fileIO

if file-exists? "mobiletowers.txt" [
  file-close-all
  file-delete "mobiletowers.txt"]

if file-exists? "agentdata.txt" [
  file-close-all
  file-delete "agentdata.txt"]

;file-open "mobiletowers.txt"

end

;************************
;*********GO*************
;************************


to go
  let loc []
  let origin []
  let desti []
  let status []   ;the status of "move" or "stop". Move: 1; Stop:0
                  ;send-car
                  ;check if cars can move whole distance
                  ;ifelse i < length(list-waypointsall) - 2 [
                  ;  set i i + 1
                  ;  set c1 item (i + 1) waypoint-all;list-waypointsall
  ;if ticks >= 14400 [ stop ]

  if ticks = 0 [random-seed 100]
  ask people [
    ;get location based on the activity schedule
    set loc table:get schedule (ticks mod 1440)
    ;print loc
    ;print loc != currentlocation
    ;print endofroute?
    ;check if the schedule requests a change of location
    if loc != currentlocation [
      (cf:match currentlocation
        cf:= "home" [set origin HomeID ask LocResidentials [hide-turtle ]]
      cf:= "work" [set origin WorkID ask LocWorks [hide-turtle ]]
      cf:= "shopping" [set origin ShopID ask Locshops [hide-turtle ]]
      cf:= "school" [set origin SchoolID ask Locschools [hide-turtle ]]
      )
      (cf:cond
        cf:case [loc = "home"] [set desti HomeID ask LocResidentials [show-turtle ]]
      cf:case [loc = "work"] [set desti WorkID ask LocWorks [show-turtle ]]
      cf:case [loc = "shopping"] [set desti ShopID ask Locshops [show-turtle ]]
      cf:case [loc = "school"] [set desti SchoolID ask Locschools [show-turtle ]]
      )
      print origin
      print desti
      set currentlocation loc
      ;create connectors between road links and origin/destination agents

      ;ask links [set color black]
      ;reset
      set endofroute? false
      set remainingdist 0
      set nextwaypoint ""
      set dummy 0
      set path 0
      set distances-to-other-waypoint 0

      ; find the shortest path
      compute-optimized-path desti origin
    ]

    ;if not end of the route then move agents
    ifelse not endofroute? [
      ;print who
      ;print endofroute?
      movepeople_checkDistance
      set status 1
    ]
    [set status 0
      if remainingdist != 0 [ ; if end of the route but small residual distance left.
        movepeople_checkDistance
      ]]

    ;data simulator
    if mobiletowerdata? [
      datacollection-mobiletowers status
    ]

    ;check zone location
    set zone [pcolor] of patch-here


    ;this is a true record of the population agent
    file-open "agentdata.txt"
    file-write time:show cur_time "yyyy-MM-dd HH:mm" file-write int(ticks / 1440) file-write (ticks mod 1440) file-write who file-write (zone) file-write (status) file-write xcor file-write ycor ;FILE-TYPE "\n"

                                                                                                                                                                   ;file-close-all
    ifelse distance min-one-of mobiletowers [distance myself] <= [radius] of min-one-of mobiletowers [distance myself] [
      file-write [who] of min-one-of mobiletowers [distance myself] FILE-TYPE "\n" ] [
      file-write "" FILE-TYPE "\n"]

;    ifelse any? mobiletowers in-radius ([radius] of one-of mobiletowers) [
;      ifelse count mobiletowers in-radius ([radius] of one-of mobiletowers) > 1 [
;        ; if a turtle is covered by two toweres, find the nearest one
;        ask min-one-of mobiletowers [distance myself] [
;
;          file-write who FILE-TYPE "\n"
;        ]
;      ] [
;      ;print count mobiletowers in-radius ([radius] of one-of mobiletowers)
;      ask mobiletowers in-radius ([radius] of one-of mobiletowers) [ ;assign a mobile tower code
;        file-write who FILE-TYPE "\n"
;      ]
;      ]] [
;    file-write "" FILE-TYPE "\n"
;      ]

    file-close-all
  ]

  tick


  set cur_time time:plus cur_time 1 "minutes"

  if ticks mod 1440 = 0 [ file-flush ] ;update the output files when a day is completed.

                                       ;if ticks > 2880 [stop]
end



to datacollection-mobiletowers [status]
  ;test if the agent is going to use the phone

  let temp []
  let temp2 []

  set temp counterMobile
  set temp2 who             ;agent id for the travelling person

  if random-float 1 <= (avg_num_calls_perday / 1440) [

    ifelse distance min-one-of mobiletowers [distance myself] <= [radius] of min-one-of mobiletowers [distance myself] [
      ask min-one-of mobiletowers [distance myself] [
      file-open "mobiletowers.txt"
      file-write time:show cur_time "yyyy-MM-dd HH:mm" file-write int(ticks / 1440) file-write (ticks mod 1440) file-write temp2 file-write temp file-write zone file-write radius file-write who file-write xcor file-write ycor FILE-TYPE "\n"   ;file-print will add a return at the end of the column
      file-close-all
      ]] [ ]

;    ifelse count mobiletowers in-radius ([radius] of one-of mobiletowers) > 1 [
;      ; if a turtle is covered by two toweres, find the nearest one
;      ask min-one-of mobiletowers [distance myself] [
;        ;current netlogo tables only take two values
;        ;table:put datarecords (word ticks "/" temp2) (word temp "/" radius "/" xcor "/" ycor "/")
;        file-open "mobiletowers.txt"
;        ;total minutes; number of days; minutes of the day; agent id; mobile tower's people's id; mobile tower's location (zone); mobile tower's signal radius; mobile tower's own id; xcor; ycor
;        file-write ticks file-write int(ticks / 1440) file-write (ticks mod 1440) file-write temp2 file-write temp file-write zone file-write radius file-write who file-write xcor file-write ycor FILE-TYPE "\n"   ;file-print will add a return at the end of the column
;        file-close-all
;      ]
;    ][
;    ask mobiletowers in-radius ([radius] of one-of mobiletowers) [ ;might need to update this if towers have their own unique radius
;                                                                   ;current netlogo tables only take two values
;                                                                   ;table:put datarecords (word ticks "/" temp2) (word temp "/" radius "/" xcor "/" ycor "/")
;      file-open "mobiletowers.txt"
;      ;total minutes; number of days; minutes of the day; agent id; mobile tower's people's id; mobile tower's location (zone); mobile tower's signal radius; mobile tower's own id; xcor; ycor
;      file-write ticks file-write int(ticks / 1440) file-write (ticks mod 1440) file-write temp2 file-write temp file-write zone file-write radius file-write who file-write xcor file-write ycor FILE-TYPE "\n"   ;file-print will add a return at the end of the column
;      file-close-all
;    ]
;    ]
  ]

end


to compute-optimized-path [desti origin]
  ;let desti []

  ;foreach sort people [

  ;  ask ? [
  ;set desti WorkID
  let temp optimized-path desti origin
  let final-distance []
  let fp []
  ;final-distance: distance
  ;fp: final path
  set final-distance item 0 temp
  set fp item 1 temp

  let t 0
  while [t < length(fp)][
    ask item t fp [
      set color yellow
      set thickness 0.3
    ]
    set t t + 1
  ]


  print (word "The shortest path between all waypoint is " fp)
  print (word "and has a length of " final-distance " meters ")
  ;  ]
  ;]

end


to-report optimized-path [desti originID]   ;can set different destinations; and also origin turtle ID for the starting point. to-report acts like a function

  let select-optimized-path []
  let list-distance []
  let list-path-waypoint []
  let list-links []
  let waypoint-count 2 ; always a orgin and a destination points
  let waypoint-next []
  let temppath []
  let tempwaypoint-all []
  let tempdistances-to-other-waypoint []


  ;let list-waypoints list homecorxy workplacecorxy ;update waypoint list
  set path[]
  let i 0
  ;let first-waypoint self
  ;create-waypoints 1 [setxy item 0 workplacecorxy item 1 workplacecorxy]
  ;ask waypoints [ hide-turtle]
  set waypoint-next turtle (desti)

  ;print waypoint-next

  ;calculate path based on weighted link length
  ask turtle originID [
    set temppath nw:weighted-path-to waypoint-next "street-length"
    print temppath
    ;calculate the turtles on the route to the waypoint
    set tempwaypoint-all nw:turtles-on-weighted-path-to waypoint-next "street-length"
    print tempwaypoint-all
    ;calculate distance (weighted by link length)
    set tempdistances-to-other-waypoint nw:weighted-distance-to waypoint-next "street-length"
    ;store the distance info
  ]
  set path temppath
  set waypoint-all tempwaypoint-all
  set distances-to-other-waypoint tempdistances-to-other-waypoint

  set list-distance lput distances-to-other-waypoint list-distance
  ;store the way point info
  set list-path-waypoint lput waypoint-next list-path-waypoint
  set list-links lput path list-links
  ;generate a list of waypoint (note: only works for two waypoints at the moment) - this is for the OD route calculation
  set list-waypointsall (map [[who] of  ? ] waypoint-all)
  ;combine distance with the way points
  let dw (map [(list ?1 ?2)] list-distance list-links)
  ;order the list by distance ascending
  let fpt sort-by [first ?1 < first ?2] dw
  ;choose the shortest path
  set select-optimized-path item 0 fpt

  ;ask waypoint-next [die]
  ;return results
  report select-optimized-path

end


to movepeople_checkDistance    ;inputs: next waypoint; remaining distance
  let newdist 0
  let distancecheck []
  let accdist []
  ;  let tempdist []
  set accdist 0
  ;  ask people [

  ;let remainingdist [distance nextwaypoint] ;calculate distance between the current location and nextwaypoint

  ifelse remainingdist >= speedcar [
    ; check if the current distance between two waypoints is longer than the speed per tick
    face nextwaypoint
    jump speedcar
    set remainingdist remainingdist - speedcar
    set endofroute? false
  ]

  [ ; if the remainingdistance is not enough to cover the distance travelled per tick

    ;finish the remaining distance before moving on to a new link
    if not (nextwaypoint = "") [
      face nextwaypoint
      jump remainingdist
    ]

    ifelse dummy < length(list-waypointsall) - 1 [

      ;check if the additional distance from next link is long enough for the current tick; if not add the link after
      while [(accdist < speedcar - remainingdist) and not endofroute?] [

        ;finish the remaining distance (if the next link is not long enough for cover the distance travelled per tick) before moving on to a new link
        if not (nextwaypoint = "") [
          face nextwaypoint
          jump newdist
          ;print newdist
        ]

        set nextwaypoint item (dummy + 1) waypoint-all ;calculate new distance to the next node
        set newdist (distance nextwaypoint)
        set accdist accdist + newdist
        ;print accdist

        ;check if reached destination
        set dummy dummy + 1
        ifelse dummy >= length(list-waypointsall) - 1 [
          set endofroute? true ]
        [set endofroute? false]

      ]

    ]
    ; last node, turtle arrived at destination
    [
      ;finish the remaining distance before moving on to a new link
      if not (nextwaypoint = "") [
        face nextwaypoint
        jump remainingdist
      ]

      set dummy dummy + 1
      set endofroute? true
      set remainingdist 0
    ]
    ;accumulated distance is bigger than speed. Move the turtle to the speed per tick distance and keep the current target node and rerun the loop to get the turtle moved

    face nextwaypoint
    ifelse (endofroute? and (accdist < speedcar - remainingdist)) [; if end of route and accumulated distance is less than the distance travelled per tick
      ifelse accdist > newdist [ ;see whether a link has been traversed.
        jump newdist]
      [jump accdist]

      set remainingdist 0  ;if end of route, do not move, destination reached

      set_path_color path black
    ]

    [ifelse accdist > newdist [; end of route, but accumulated distance is more than the distance travelled per tick
      jump speedcar - remainingdist - (accdist - newdist)]
    [  jump speedcar - remainingdist]

    set remainingdist remainingdist + accdist - speedcar]

    set accdist 0
    set newdist 0
  ]
  ;  ]

end

to set_path_color [linklist colorname]
  let t 0
  ;print length(linklist)
  while [t < length(linklist)][
    ;print "black"
    ask item t linklist [
      set color colorname
    ;  set thickness 0.3
    ]
    set t t + 1
  ]

end
@#$#@#$#@
GRAPHICS-WINDOW
215
10
696
512
40
40
5.815
1
10
1
1
1
0
0
0
1
-40
40
-40
40
1
1
1
ticks
30.0

BUTTON
10
10
105
43
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
10
130
187
163
Show_Names_Nodes?
Show_Names_Nodes?
1
1
-1000

BUTTON
17
405
165
438
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
11
174
190
207
Show_Names_people?
Show_Names_people?
1
1
-1000

INPUTBOX
129
62
205
122
nb-people
1
1
0
Number

INPUTBOX
11
62
99
122
grid-size
21
1
0
Number

INPUTBOX
10
221
93
281
car-speed
1
1
0
Number

MONITOR
129
10
206
55
Time
word (floor ((ticks mod 1440) / 60)) \":\" ((ticks mod 1440) mod 60)
17
1
11

SWITCH
712
10
866
43
mobiletowerdata?
mobiletowerdata?
0
1
-1000

SWITCH
991
11
1147
44
socialmedia_data?
socialmedia_data?
0
1
-1000

INPUTBOX
713
54
840
114
grids_covered_vector
5
1
0
Number

INPUTBOX
854
55
976
115
avg_num_calls_perday
5
1
0
Number

INPUTBOX
714
123
841
183
avg_call_duration_mins
2
1
0
Number

@#$#@#$#@
## WHAT IS IT?

This model uses the Dijkstra’s algorithm of the Netlogo Network extension to compute the optimal path between several waypoints.

## HOW IT WORKS

It selects one waypoint as a starting point, learns the shortest paths to every other waypoint, selects the closest one and iterates from the latter until all waypoints are visited. To ensure that all paths are considered the simulation is run so that every waypoint is tested as the starting point. These paths are compared and the shortest one is selected as the optimal path between all waypoints.

## HOW TO USE IT

GRID-SIZE – Controls the extent of the network

NB-WAYPOINTS – Controls the number of waypoints to be created

SHOW_NAMES_NODES? – Determined whether or not the “Who” attribute of each node is displayed

SHOW_NAMES_WAYPOINTS? - Determined whether or not the “Who” attribute of each waypoint is displayed


## THINGS TO TRY

Try running the model with more or less waypoints.

Try different sizes of grid.


## NETLOGO FEATURES

The code used to setup the initial grid of nodes forming the network was based on the “Diffusion on a Directed Network” model available in the Model Library.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.3.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

small-arrow-link
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 120 180
Line -7500403 true 150 150 180 180

@#$#@#$#@
0
@#$#@#$#@
