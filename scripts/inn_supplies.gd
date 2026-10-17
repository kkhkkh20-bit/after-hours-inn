extends RefCounted
## GLoot is the inventory authority; portable counts are mirrored into the inn save.
const GOODS={"food":{"name":"식재료","amount":10,"price":4},"fuel":{"name":"장작","amount":10,"price":3},"medicine":{"name":"약품","amount":3,"price":5}}
var host
var inventory: Inventory
var signature=""
var button: Button
func setup(h) -> void:
	host=h;inventory=Inventory.new();inventory.name="InnStock";h.add_child(inventory)
	var proto=JSON.new();proto.data={"food":{"max_stack_size":999},"fuel":{"max_stack_size":999},"medicine":{"max_stack_size":999}};inventory.protoset=proto
	button=h.object_context.button_("창고",h.builder.root,func():open(),88);button.position=Vector2(24,1248);button.size=Vector2(164,88);button.custom_minimum_size=Vector2(164,88)
func ensure(s) -> void:
	if not s.data.has("supplies"):s.data.supplies={"food":24,"fuel":24,"medicine":4,"auto":true}
	var current=var_to_str(s.data.supplies)
	if signature==current:return
	inventory.clear()
	for key in GOODS:
		var count_=clampi(int(s.data.supplies.get(key,0)),0,999)
		if count_>0:
			var item=inventory.create_and_add_item(key);item.set_stack_size(count_)
	signature=current
func sync(s) -> void:
	for key in GOODS:
		var item=inventory.get_item_with_prototype_id(key);s.data.supplies[key]=item.get_stack_size() if item!=null else 0
	signature=var_to_str(s.data.supplies)
func count(s,key: String) -> int:
	ensure(s);var item=inventory.get_item_with_prototype_id(key);return item.get_stack_size() if item!=null else 0
func buy(s,key: String) -> bool:
	ensure(s)
	if not GOODS.has(key):return false
	var good: Dictionary=GOODS[key]
	if s.data.money<int(good.price):s.note("구매할 돈이 부족합니다.");return false
	if count(s,key)+int(good.amount)>999:s.note("창고가 가득 찼습니다.");return false
	var item=inventory.get_item_with_prototype_id(key)
	if item==null:item=inventory.create_and_add_item(key);item.set_stack_size(int(good.amount))
	else:item.set_stack_size(item.get_stack_size()+int(good.amount))
	s.data.money-=int(good.price);sync(s);s.note("%s %d개 입고" %[good.name,good.amount]);return true
func take(s,key: String,amount: int=1) -> bool:
	ensure(s)
	if count(s,key)<amount and bool(s.data.supplies.auto):buy(s,key)
	if count(s,key)<amount:s.note("%s 부족 · 창고에서 보충하세요." %GOODS[key].name);return false
	var item=inventory.get_item_with_prototype_id(key)
	if item.get_stack_size()==amount:inventory.remove_item(item)
	else:item.set_stack_size(item.get_stack_size()-amount)
	sync(s);return true
func summary() -> String:
	var s=host.sim;ensure(s)
	return "식재료 %d · 장작 %d · 약품 %d\n식사에 식재료 1개, 화로에 장작 2개 사용\n자동 보충: %s" %[count(s,"food"),count(s,"fuel"),count(s,"medicine"),"켜짐" if s.data.supplies.auto else "꺼짐"]
func items() -> Array:
	var result=[]
	for key in GOODS:
		var good: Dictionary=GOODS[key];result.append(["stock:"+key,"%s %d개 구매 · %d닢" %[good.name,good.amount,good.price]])
	result.append(["stock:auto","자동 보충 · "+("켜짐" if host.sim.data.supplies.auto else "꺼짐")]);return result
func open() -> void:host.builder.close();host.object_context.open("supplies","",summary())
func update() -> void:
	button.visible=not host.builder.active and not host.journal.opened and not host.object_context.panel.visible
func shutdown() -> void:
	if not is_instance_valid(inventory):return
	inventory.clear()
	inventory.get_prototree().clear()
	preload("res://addons/gloot/core/prototree/proto_tree_cache.gd")._cache.erase(inventory.protoset)
