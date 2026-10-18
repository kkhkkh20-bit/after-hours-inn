/* Original OpenClonk map API: no custom collision or terrain engine. */
#include Library_Map
protected func InitializeMap(proplist map)
{
 map->Resize(150, 100);
 Draw("Earth", {Algo=MAPALGO_Rect, X=0, Y=35, Wdt=150, Hgt=65});
 Draw("Rock", {Algo=MAPALGO_Rect, X=0, Y=75, Wdt=150, Hgt=25});
 // The upper guest floor and two clear staircase gaps.
 Draw("Brick", {Algo=MAPALGO_Rect, X=51, Y=26, Wdt=52, Hgt=1});
 // Cellar and workshop: open rooms, solid earth left for player expansion.
 Draw("Tunnel", {Algo=MAPALGO_Rect, X=35, Y=46, Wdt=74, Hgt=10});
 Draw("Tunnel", {Algo=MAPALGO_Rect, X=48, Y=34, Wdt=3, Hgt=22});
 Draw("Tunnel", {Algo=MAPALGO_Rect, X=104, Y=34, Wdt=3, Hgt=22});
 Draw("Tunnel", {Algo=MAPALGO_Rect, X=53, Y=62, Wdt=27, Hgt=9});
 Draw("Tunnel", {Algo=MAPALGO_Rect, X=78, Y=55, Wdt=3, Hgt=16});
 Draw("Gold", {Algo=MAPALGO_Rect, X=104, Y=69, Wdt=13, Hgt=7});
 Draw("Ore", {Algo=MAPALGO_Rect, X=21, Y=62, Wdt=10, Hgt=10});
 Draw("Coal", {Algo=MAPALGO_Rect, X=39, Y=75, Wdt=11, Hgt=6});
 return true;
}
