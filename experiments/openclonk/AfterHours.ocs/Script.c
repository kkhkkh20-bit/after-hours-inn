/* After Hours: scenario layer on the COMPLETE OpenClonk 8.1 game.
   Native terrain, physics, commands, tools, construction, containers and dialogues. */
static inn_owner, inn_staff, inn_store, inn_rooms, inn_guests;
static inn_tick, inn_food, inn_help, inn_rent, inn_served, inn_day, inn_hud, inn_camera;

func Initialize()
{
 inn_rooms = []; inn_guests = []; inn_food = 12; inn_tick = 0;
 inn_served = 0; inn_day = 1; inn_help = false; inn_rent = false;
 CreateObject(Rule_NoPowerNeed);
 GUI_Controller->ShowWealth();
 var clock = CreateObject(Time); clock->SetTime(16 * 60); clock->SetCycleSpeed(1);
 // Ground floor: kitchen, reception/storage, courtyard workbench.
 CreateObjectAbove(Kitchen, 350, 280, NO_OWNER);
 inn_store = CreateObjectAbove(Chest, 435, 280, NO_OWNER);
 inn_store.Name = "Reception supplies"; inn_store.MaxContentsCount = 200;
 inn_store->CreateContents(Bread, 12);
 inn_store->CreateContents(Wood, 30);
 inn_store->CreateContents(Metal, 20);
 inn_store->CreateContents(Rock, 30);
 CreateObjectAbove(ToolsWorkshop, 930, 280, NO_OWNER);
 CreateObjectAbove(Windmill, 1080, 280, NO_OWNER);
 for (var x in [460, 540, 620, 700, 780])
 {
  var room = CreateObjectAbove(WoodenCabin, x, 208, NO_OWNER);
  room.InnIndex = GetLength(inn_rooms) + 1;
  room.Name = Format("Room %d - vacant", room.InnIndex);
  PushBack(inn_rooms, room);
 }
 // Original climbable ladders: guest stairs, pantry shaft, yard shaft, deeper room.
 InnLadder(395, 238, 10); InnLadder(840, 238, 10);
 InnLadder(395, 364, 22); InnLadder(844, 364, 22);
 InnLadder(635, 501, 18);
 CreateObjectAbove(Hatch, 395, 284, NO_OWNER);
 CreateObjectAbove(Hatch, 844, 284, NO_OWNER);
 // These are real native structures, usable with their original menus/tools.
 CreateObjectAbove(Chest, 340, 448, NO_OWNER)->CreateContents(Wood, 20);
 CreateObjectAbove(Foundry, 480, 448, NO_OWNER);
 CreateObjectAbove(InventorsLab, 600, 448, NO_OWNER);
 CreateObjectAbove(Chest, 710, 448, NO_OWNER)->CreateContents(Metal, 12);
 CreateObjectAbove(StoneDoor, 580, 568, NO_OWNER);
 for (var p in [[395,425], [540,425], [740,425], [610,545]])
 {
  var light = CreateObjectAbove(Lantern, p[0], p[1], NO_OWNER);
  light->SetCategory(C4D_StaticBack); light->TurnOn();
 }
 inn_staff = CreateObjectAbove(Clonk, 455, 280, NO_OWNER);
 inn_staff->SetName("Mara - inn assistant"); inn_staff->SetSkin(1);
 inn_staff.InnStaff = true; inn_staff->SetCategory(inn_staff->GetCategory() | C4D_MouseSelect);
 inn_staff->SetDialogue("InnStaff", true);
 // Road and yard remain open; all new visitors walk in from the left.
 for (var x in [60, 135, 1130]) CreateObjectAbove(Tree_Coniferous, x, 280, NO_OWNER);
 Schedule(nil, "GameCall(\"InnClock\")", 36, 999999);
 DebugLog("INN READY: native terrain; 5 rooms; 2 cellar entrances; workshop; storage.");
 return true;
}
func InnLadder(int x, int y, int count)
{
 var ladder = CreateObject(MetalLadder, x, y, NO_OWNER);
 ladder->SetLength(count, 0);
 return ladder;
}
func InitializePlayer(int plr)
{
 inn_owner = plr;
 var crew = GetCrew(plr);
 crew->SetPosition(485, 269);
 if (SCENPAR_StartInCellar) crew->SetPosition(850, 437); crew->SetName("Innkeeper");
 crew->CreateContents(Shovel); crew->CreateContents(Hammer);
 crew->CreateContents(Pickaxe); crew->CreateContents(Axe); crew->CreateContents(Lantern);
 SetWealth(plr, 500);
 GivePlayerAllKnowledge(plr);
 SetPlayerZoomByViewRange(plr, 1100, 670, PLRZOOM_Direct | PLRZOOM_Set | PLRZOOM_LimitMax);
 SetPlayerViewLock(plr, true);
 SetFoW(false, plr);
 inn_camera = CreateObject(Dummy, 600, 360);
 SetPlrView(plr, inn_camera);
 InnShowHUD();
 InnStatus();
 return true;
}
func GivePlayerAllKnowledge(int plr)
{
 var index = 0, def;
 while (def = GetDefinition(index++)) SetPlrKnowledge(plr, def);
}
func InnClock()
{
 if (inn_owner == nil) return;
 inn_tick++;
 if (inn_tick % 14 == 3) InnArrival();
 if (inn_tick % 20 == 0) for (var debug_guest in inn_guests) if (debug_guest) DebugLog("INN STATE: %s at %d,%d action %s", debug_guest.InnState, debug_guest->GetX(), debug_guest->GetY(), debug_guest->GetAction());
 for (var guest in inn_guests)
 {
  if (!guest) continue;
  // Native ladder-climbing action needs a direction from NPC policy.
  if (guest.InnState == "staying" && guest.InnRoom)
  {
   if (guest->GetAction() == "Climb" && guest->GetY() > 198)
   { guest->SetCommand("None"); guest->SetComDir(COMD_Up); guest.InnClimbing = true; }
   if (guest.InnClimbing && guest->GetY() <= 214)
   {
    guest.InnClimbing = false;
    RemoveEffect("IntClimbControl", guest);
    guest->ControlJump();
    var side = 5; if (guest.InnRoom->GetX() < guest->GetX()) side = -5;
    guest->SetXDir(side);
    guest->SetCommand("MoveTo", nil, guest.InnRoom->GetX(), 197);
   }
  }
  if (guest.InnState == "leaving")
  {
   if (guest->GetAction() == "Climb" && guest->GetY() < 260)
   { guest->SetCommand("None"); guest->SetComDir(COMD_Down); guest.InnClimbing = true; }
   if (guest.InnClimbing && guest->GetY() >= 260)
   { guest.InnClimbing = false; guest->SetCommand("MoveTo", nil, 90, 269); }
  }
  if (guest.InnState == "arriving" && guest->GetX() > 450)
  {
   guest.InnState = "waiting";
   var dest = 490; if (guest.InnMeal) dest = 350;
   guest->SetCommand("MoveTo", nil, dest, 269);
  }
  if (inn_help && guest.InnState == "waiting") InnServe(guest, GetCursor(inn_owner));
  if (guest.InnUntil && inn_tick >= guest.InnUntil && guest.InnState != "leaving")
  {
   if (guest.InnRoom) { guest.InnRoom.InnBusy = false; guest.InnRoom.Name = Format("Room %d - vacant", guest.InnRoom.InnIndex); }
   guest.InnRoom = nil; guest.InnState = "leaving";
   guest->SetCommand("MoveTo", nil, 90, 269);
  }
  if (guest.InnState == "leaving" && guest->GetX() < 110) guest->RemoveObject();
 }
 // One operational day = 180 seconds. Existing rooms are reusable after checkout.
 if (inn_tick % 180 == 0)
 {
  if (!inn_rent) { DoWealth(inn_owner, -120); DebugLog("RENT: 120 collected."); }
  inn_day++; inn_rent = false;
 }
 InnStatus();
 return true;
}
func InnArrival()
{
 var active = 0;
 for (var guest in inn_guests) if (guest && guest.InnState != "leaving") active++;
 if (active >= 8) return;
 var guest = CreateObjectAbove(Clonk, 140, 280, NO_OWNER);
 guest.InnMeal = (inn_tick / 14) % 3 == 0;
 guest.InnState = "arriving";
 guest->SetSkin((inn_tick / 14) % 4);
 guest->SetName("Traveller - room");
 if (guest.InnMeal) guest->SetName("Traveller - meal");
 guest->SetCategory(guest->GetCategory() | C4D_MouseSelect);
 guest->SetDialogue("InnGuest", true);
 guest->SetCommand("MoveTo", nil, 480, 269);
 PushBack(inn_guests, guest);
 DebugLog("ARRIVAL: %s", guest->GetName());
}
func InnServe(object guest, object crew)
{
 if (!guest || guest.InnState == "leaving") return "This traveller is leaving.";
 if (guest.InnState == "staying" || guest.InnState == "eating") return "Already served. They will leave on their own.";
 if (guest.InnMeal)
 {
  inn_food = inn_store->ContentsCount(Bread);
  if (inn_food < 1) return "No food. Ask Mara to restock.";
  inn_store->FindContents(Bread)->RemoveObject(); inn_food = inn_store->ContentsCount(Bread); DoWealth(inn_owner, 12); inn_served++;
  guest.InnState = "eating"; guest.InnUntil = inn_tick + 20;
  guest->SetCommand("MoveTo", nil, 350, 269);
  guest->SetName("Dining - paid 12");
  DebugLog("MEAL: paid 12; food %d", inn_food);
  return "A meal for 12 coins. I will eat at the kitchen and leave.";
 }
 for (var room in inn_rooms)
 {
  if (!room.InnBusy)
  {
   room.InnBusy = true; guest.InnRoom = room;
   room.Name = Format("Room %d - occupied", room.InnIndex);
   guest.InnState = "staying"; guest.InnUntil = inn_tick + 65;
   guest->SetCommand("MoveTo", nil, room->GetX(), 197);
   guest->SetName(Format("Room %d - paid 35", room.InnIndex));
   DoWealth(inn_owner, 35); inn_served++;
   DebugLog("BOOKED: Room %d; paid 35", room.InnIndex);
   return Format("Room %d, 35 coins. I will check out shortly.", room.InnIndex);
  }
 }
 guest.InnState = "leaving"; guest->SetCommand("MoveTo", nil, 90, 269);
 return "Full tonight. I will try another inn.";
}
func InnTurnAway(object guest)
{
 if (!guest) return;
 if (guest.InnRoom) { guest.InnRoom.InnBusy = false; guest.InnRoom.Name = Format("Room %d - vacant", guest.InnRoom.InnIndex); }
 guest.InnRoom = nil; guest.InnState = "leaving";
 guest->SetCommand("MoveTo", nil, 90, 269);
}
func InnHire()
{
 if (inn_help) return "I am already handling check-in and meals.";
 if (GetWealth(inn_owner) < 30) return "Need 30 coins.";
 DoWealth(inn_owner, -30); inn_help = true; InnStatus();
 return "I will handle guests and turn them away when full. You can work below.";
}
func InnRestock()
{
 if (GetWealth(inn_owner) < 10) return "Need 10 coins.";
 DoWealth(inn_owner, -10); inn_store->CreateContents(Bread, 10); inn_food = inn_store->ContentsCount(Bread); InnStatus();
 return "Ten meals added to the pantry.";
}
func InnRent()
{
 if (inn_rent) return "Today's rent is already paid.";
 if (GetWealth(inn_owner) < 120) return "Need 120 coins.";
 DoWealth(inn_owner, -120); inn_rent = true; InnStatus();
 return "Rent paid. Keep the inn open while you expand the cellar.";
}
func InnHideHUD()
{
 if (inn_hud) GuiClose(inn_hud);
 inn_hud = nil;
}
func InnShowHUD()
{
 if (!inn_hud) inn_hud = GuiOpen({Player=inn_owner, Left="1em", Right="47em", Top="6em", Bottom="9em", Style=GUI_Multiple | GUI_TextLeft, BackgroundColor=0xb0201810});
}
func InnStatus()
{
 inn_food = inn_store->ContentsCount(Bread);
 var busy = 0;
 for (var room in inn_rooms) if (room.InnBusy) busy++;
 var helper_text = "OFF", rent_text = "120 due";
 if (inn_help) helper_text = "ON";
 if (inn_rent) rent_text = "PAID";
 var text = Format("Day %d   Rooms %d/5   Food %d   Served %d|Helper %s   Rent %s   Click Mara / a traveller", inn_day, busy, inn_food, inn_served, helper_text, rent_text);
 if (inn_hud) GuiUpdate({Text=text}, inn_hud);
}
