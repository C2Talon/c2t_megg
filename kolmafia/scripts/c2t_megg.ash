//c2t_megg
//c2t

//mimic egg interfaces

since r27795;//egg preferences

//cli flag
boolean c2t_megg_CLI = false;

//globals to be set when a primary functions ran
familiar c2t_megg_oldFam;
item c2t_megg_oldEq;


//donate max eggs on hand of mon
//returns false only on critical errors
boolean c2t_megg_donate(monster target);
//for random donating max eggs on hand
//returns false only on critical errors
boolean c2t_megg_donate() return c2t_megg_donate($monster[none]);

//extract egg
//returns true if egg taken; false on failure
boolean c2t_megg_extract(monster target);

//fight egg
//returns true only if entered combat with it
//does not actually do the combat
boolean c2t_megg_fight(monster target);

//function to put into pre-adventure scripts to update list of max donated eggs
//has a speed bump built in to help try to keep the list updated passively and to not hit the server too frequently
//to change the frequency of the time limiter, the preference c2t_megg_timeLimit can be changed from the default of 30 minutes
//returns true only if the data file successfully updated
boolean c2t_megg_preAdv();

//attempts to update the list of max donated eggs
//returns true only if the data file successfully updated
boolean c2t_megg_update();


//for error messages and clean exit
boolean c2t_megg_error(string s);

//for success messages and clean exit
boolean c2t_megg_success(string s);
boolean c2t_megg_success() return c2t_megg_success("");

//for relay overrides
string c2t_megg_relay(string page);
string c2t_megg_relayFight(string page);

//print
void c2t_megg_print(string s);

//mafia's xpath won't let me just grab from one form directly without this workaround
boolean c2t_megg_isExtractPage(buffer page);
boolean c2t_megg_isDonatePage(buffer page);
int c2t_megg_numForms(buffer buf);

//gets list of max eggs from page
boolean[string] c2t_megg_readPage(buffer page);

//read/write data file for keeping track of maxed eggs
boolean[string] c2t_megg_readFile();
boolean c2t_megg_writeFile(boolean[string] map);

//init
void c2t_megg_init();


//CLI
void main(string args) {
	c2t_megg_CLI = true;
	string[int] split;
	string action,target;
	monster mon;

	split = split_string(args," ");
	action = split[0].to_lower_case();

	for (int i = 1;i <= split.count()-1;i++)
		target += i == 1 ? split[i] : ` {split[i]}`;

	target = target.to_lower_case();
	mon = target == "random"
		? $monster[none]
		: target.to_monster();

	switch (action) {
		default:
			c2t_megg_print(`"{action}" is an invalid command`);
		case "help":
			print("available commands for c2t_megg:");
			print("c2t_megg donate [monster] -- used to donate mimic eggs of monster, or random if monster omitted");
			print("c2t_megg extract <monster> -- used to extract mimic egg of monster from Mimic DNA Bank");
			print("c2t_megg fight <monster> -- enter combat with monster contained in a mimic egg");
			print("c2t_megg preadv -- updates the maxed egg list if able, but with time restictions useful for pre-adventure scripts");
			print("c2t_megg update -- updates the maxed egg list if able");
			print("c2t_megg cleaner <on|off> -- turn the relay cleaner on or off; the cleaner removes the beginning article in monster names and makes the drop-down menus searchable when visiting the Mimic DNA Bank");
			print("c2t_megg help -- displays this list of commands");
			break;
		case "donate":
		case "donegg":
			c2t_megg_donate(mon);
			break;
		case "extract":
		case "eggtract":
		case "eggstract":
			c2t_megg_extract(mon);
			break;
		case "fight":
			c2t_megg_fight(mon);
			break;
		case "pre":
		case "preadv":
		case "preadventure":
		case "pre-adventure":
			c2t_megg_preAdv();
			break;
		case "update":
			c2t_megg_update();
			break;
		case "cleaner":
			switch (target) {
				default:
					c2t_megg_print(`"{target}" is an invalid relay cleaner option`);
					break;
				case "on":
					set_property("c2t_megg_disableRelayCleaner",false);
					c2t_megg_print("relay cleaner on");
					break;
				case "off":
					set_property("c2t_megg_disableRelayCleaner",true);
					c2t_megg_print("relay cleaner off");
					break;
			}
			break;
	}
}

boolean c2t_megg_donate(monster target) {
	item egg = $item[mimic egg];
	familiar mimic = $familiar[chest mimic];
	string pref = "_mimicEggsDonated";
	buffer page;
	boolean[string] maxlist;
	string[int] options;
	string monstring;
	int start,needle,size;
	int tries = 0;
	int MAX_TRIES = 4;
	int numForms = 0;
	boolean roundtrip = false;

	c2t_megg_init();
	maxlist = c2t_megg_readFile();
	monstring = target.id.to_string();

	//maybe don't have to go
	if (!have_familiar(mimic))
		return c2t_megg_error("no chest mimic detected");
	if (get_property(pref).to_int() >= 3)
		return c2t_megg_success("max daily eggs donated already");
	if (item_amount(egg) == 0)
		return c2t_megg_success("no eggs on hand to donate");
	if (maxlist contains monstring)
		return c2t_megg_success(`{target} eggs already max donated`);

	//go
	use_familiar(mimic);
	page = visit_url("place.php?whichplace=town_right&action=townright_dna",false,true);

	//choice check
	if (!handling_choice()
		|| last_choice() != 1517)
	{
		return c2t_megg_error("couldn't enter choice adventure to donate eggs");
	}

	//forms check
	if (!page.c2t_megg_isDonatePage())
		return c2t_megg_error("no donation interface detected; mafia out of sync?");
	else
		numForms++;
	if (page.c2t_megg_isExtractPage()) {
		numForms++;
		maxlist = page.c2t_megg_readPage();
		c2t_megg_writeFile(maxlist);
	}

	//some default protection against max egg redundancies for random donate
	if (target == $monster[none]
		&& maxlist.count() == 0)
	{
		c2t_megg_print("couldn't read max egg list from page or data file, so protecting embezzlers at minimum");
		maxlist[$monster[knob goblin embezzler].id.to_string()] = true;
	}

	//target already max check
	if (maxlist contains monstring)
		return c2t_megg_success(`{target} already max donated`);

	//do the things
	if (target != $monster[none]) {//not random donation
		repeat {
			if (!page.contains_text(`<option value="{monstring}">`))//precarious match
				return c2t_megg_success(`no more {target} eggs left to donate`);
			c2t_megg_print(`donating egg of {target}`);
			page = visit_url(`choice.php?pwd&whichchoice=1517&option=1&mid={monstring}`,true,true);
		} until (item_amount(egg) == 0
			|| get_property(pref).to_int() >= 3
			|| ++tries >= MAX_TRIES);
	}
	else repeat {//random donation
		options = xpath(page,`//form[@action="choice.php"][{numForms}]/select/option/@value`);
		size = options.count();
		needle = start = size == 2 ? 1 : random(size-1)+1;
		repeat {
			monstring = options[needle];
			if (!(maxlist contains monstring)) {
				c2t_megg_print(`donating egg of {monstring.to_monster()}`);
				page = visit_url(`choice.php?pwd&whichchoice=1517&option=1&mid={monstring}`,true,true);
				break;
			}
			if (++needle > size-1)
				needle = 1;
		} until (needle == start
			&& roundtrip = true);
		if (roundtrip)
			return c2t_megg_success("all eggs you have appear to be max donated already");
	} until (item_amount(egg) == 0
		|| get_property(pref).to_int() >= 3
		|| ++tries >= MAX_TRIES);//just in case logic is off or there is a desync with mafia, don't let this loop infinitely

	//result
	if (get_property(pref).to_int() >= 3)
		return c2t_megg_success("max daily eggs donated");
	if (item_amount(egg) == 0)
		return c2t_megg_success("ran out of eggs to donate");
	if (tries >= MAX_TRIES)
		return c2t_megg_error(`mafia out of sync? tried to donate {tries} times without fully succeeding`);

	//something happened that I didn't think of; or something to do with protection
	c2t_megg_print(`{get_property(pref)},{item_amount(egg)},{tries},{monstring},{options.count()}`);
	return c2t_megg_error("maximum overfail");
}

boolean c2t_megg_extract(monster target) {
	item egg = $item[mimic egg];
	familiar mimic = $familiar[chest mimic];
	string pref = "_mimicEggsObtained";
	buffer page;
	boolean[string] maxlist;
	string monstring;
	int start;

	c2t_megg_init();

	//maybe don't need to go
	if (!have_familiar(mimic))
		return c2t_megg_error("no chest mimic detected");
	if (target == $monster[none])
		return c2t_megg_error("cannot extract none");
	if (get_property(pref).to_int() >= 11)
		return c2t_megg_success("already at max daily extractions");
	if (mimic.experience == 0) {
		c2t_megg_print("chest mimic detected with no experience; refreshing terrarium");
		cli_execute("refresh terrarium");
	}
	if (mimic.experience < 100)
		return c2t_megg_error("not enough familiar experience");

	//go
	use_familiar(mimic);
	page = visit_url("place.php?whichplace=town_right&action=townright_dna",false,true);

	//choice check
	if (!handling_choice()
		|| last_choice() != 1517)
	{
		return c2t_megg_error("couldn't enter choice adventure to extract eggs");
	}

	//form check
	if (!page.c2t_megg_isExtractPage())
		return c2t_megg_error("couldn't find the extract egg interface");

	//make maxlist
	maxlist = page.c2t_megg_readPage();
	c2t_megg_writeFile(maxlist);
	monstring = target.id.to_string();

	//is it extractable
	if (!(maxlist contains monstring))
		return c2t_megg_error(`{target} not extractable (yet?)`);

	start = item_amount(egg);
	page = visit_url(`choice.php?pwd&whichchoice=1517&option=2&mid={monstring}`,true,true);
	if (start < item_amount(egg))
		return c2t_megg_success(`extracted {target} egg`);

	return c2t_megg_error(`unknown error extracting {target}`);
}

boolean c2t_megg_fight(monster target) {
	item egg = $item[mimic egg];
	buffer page;
	string monstring;

	c2t_megg_init();

	//maybe don't need to go
	if (item_amount(egg) == 0)
		return c2t_megg_error("no mimic eggs to fight");
	if (target == $monster[none])
		return c2t_megg_error("cannot fight none");
	if (my_hp() == 0)
		return c2t_megg_error("entering combat with zero HP is an instant loss");

	//go
	page = visit_url(`inv_use.php?pwd={my_hash()}&which=3&whichitem={egg.id}`,false,true);

	//choice check
	if (!handling_choice()
		|| last_choice() != 1516)
	{
		return c2t_megg_error("couldn't enter choice adventure to fight eggs");
	}

	//check if available
	monstring = target.id.to_string();
	if (!page.contains_text(`<option value="{monstring}">`)) {
		visit_url("main.php",false,true);//don't get stuck in choice
		return c2t_megg_error(`{target} not found to fight`);
	}

	page = visit_url(`choice.php?pwd&whichchoice=1516&option=1&mid={monstring}`,true,true);
	return current_round() > 0;
}

boolean c2t_megg_preAdv() {
	familiar mimic = $familiar[chest mimic];
	string prefLast = "_c2t_megg_lastCheck";
	string prefLimit = "c2t_megg_timeLimit";
	boolean[string] maxlist;
	buffer page;
	int last = get_property(prefLast).to_int();
	int limit = get_property(prefLimit).to_int() * 60000;
	int now = now_to_int();
	boolean dailyMaxed = get_property("_mimicEggsObtained").to_int() >= 11;

	//maybe don't need to go
	if (!have_familiar(mimic))
		return false;
	if (mimic.experience < 100)
		return false;
	if (dailyMaxed)
		return false;
	//30 minutes speed limit to start
	if (limit == 0) {
		limit = 600000;
		set_property(prefLimit,30);
	}
	//don't check too often
	if (now - last < limit)
		return false;

	//go
	c2t_megg_init();
	use_familiar(mimic);
	page = visit_url("place.php?whichplace=town_right&action=townright_dna",false,true);

	//choice check
	if (!handling_choice()
		|| last_choice() != 1517)
	{
		return c2t_megg_error("could not enter choice adventure to record maxed eggs");
	}

	//form check
	if (!page.c2t_megg_isExtractPage())
		return c2t_megg_error("could not find extract interfact to record maxed eggs");

	//read/write
	maxlist = page.c2t_megg_readPage();
	c2t_megg_writeFile(maxlist);

	//make sure it actually happened
	if (maxlist.count() == 0)
		return c2t_megg_error("could not read extract interfact to record maxed eggs");

	//update last check
	return c2t_megg_success(`pre-adventure success`);
}

boolean c2t_megg_update() {
	familiar mimic = $familiar[chest mimic];
	boolean[string] maxlist;
	buffer page;
	boolean dailyMaxed = get_property("_mimicEggsObtained").to_int() >= 11;

	c2t_megg_init();

	//maybe don't need to go
	if (!have_familiar(mimic))
		return c2t_megg_error("no chest mimic detected");
	if (mimic.experience < 100)
		return c2t_megg_error("not enough familiar experience");
	if (dailyMaxed)
		return c2t_megg_error("daily max eggs obtained; can't update list anymore today");

	//go
	use_familiar(mimic);
	page = visit_url("place.php?whichplace=town_right&action=townright_dna",false,true);

	//choice check
	if (!handling_choice()
		|| last_choice() != 1517)
	{
		return c2t_megg_error("could not enter choice adventure to record maxed eggs");
	}

	//form check
	if (!page.c2t_megg_isExtractPage())
		return c2t_megg_error("could not find extract interfact to record maxed eggs");

	//read/write
	maxlist = page.c2t_megg_readPage();
	//writeFile has its own (useful) success message
	if (c2t_megg_writeFile(maxlist))
		return c2t_megg_success();
	return c2t_megg_error("failed to update maxed egg list");
}

string c2t_megg_relay(string page) {
	buffer buf = page.to_buffer();
	boolean[string] maxlist;

	if (buf.c2t_megg_isExtractPage()) {
		maxlist = buf.c2t_megg_readPage();
		maxlist.c2t_megg_writeFile();
	}

	if (get_property("c2t_megg_disableRelayCleaner").to_boolean())
		return page;

	if (maxlist.count() == 0)
		maxlist = c2t_megg_readFile();

	matcher m;

	//remove articles from the start of monster names
	m = create_matcher("(<option[^>]+>)([Aa]n?|[Tt]he)\\s+",buf);
	buf = replace_all(m,"$1").to_buffer();

	//disable maxed eggs in donate section
	m = create_matcher('(<option value="(\\d+)")(>.*?)\\s*</option>',buf);
	while (m.find())
		if (maxlist contains m.group(2))
			buf.replace_string(`{m.group(1)}{m.group(3)}`,`{m.group(1)} disabled{m.group(3)} (max)`);

	//make select searchable
	buf.replace_string("</head>",'<script src="https://code.jquery.com/jquery-3.7.1.min.js"></script><link href="https://cdn.jsdelivr.net/npm/select2@4.1.0-rc.0/dist/css/select2.min.css" rel="stylesheet" /><script src="https://cdn.jsdelivr.net/npm/select2@4.1.0-rc.0/dist/js/select2.min.js"></script><script type="text/javascript">var jQuery_3_7_1 = $.noConflict(true);jQuery_3_7_1(document).ready(function() {jQuery_3_7_1(\'.searchable-select\').select2();});</script></head>');
	buf.replace_string('<select name="mid">','<select class="searchable-select" name="mid">');

	return buf.to_string();
}

string c2t_megg_relayFight(string page) {
	buffer buf = page.to_buffer();
	//make select searchable
	buf.replace_string("</head>",'<script src="https://code.jquery.com/jquery-3.7.1.min.js"></script><link href="https://cdn.jsdelivr.net/npm/select2@4.1.0-rc.0/dist/css/select2.min.css" rel="stylesheet" /><script src="https://cdn.jsdelivr.net/npm/select2@4.1.0-rc.0/dist/js/select2.min.js"></script><script type="text/javascript">var jQuery_3_7_1 = $.noConflict(true);jQuery_3_7_1(document).ready(function() {jQuery_3_7_1(\'.searchable-select\').select2();});</script></head>');
	buf.replace_string('<select name="mid">','<select class="searchable-select" name="mid">');
	return buf.to_string();
}

boolean c2t_megg_error(string s) {
	string msg = "c2t_megg error: "+s;
	use_familiar(c2t_megg_oldFam);
	equip($slot[familiar],c2t_megg_oldEq);

	if (c2t_megg_CLI)
		abort(msg);

	print(msg,"red");
	return false;
}

boolean c2t_megg_success(string s) {
	use_familiar(c2t_megg_oldFam);
	equip($slot[familiar],c2t_megg_oldEq);
	if (s != "")
		c2t_megg_print(s);
	return true;
}

void c2t_megg_print(string s) {
	print("c2t_megg: "+s);
}

boolean c2t_megg_isExtractPage(buffer page) {
	return page.contains_text('Extract an egg containing the dna of <select name="mid">');
}

boolean c2t_megg_isDonatePage(buffer page) {
	return page.contains_text('Donate the egg of <select name="mid">');
}

int c2t_megg_numForms(buffer page) {
	return page.c2t_megg_isDonatePage().to_int() + page.c2t_megg_isExtractPage().to_int();
}

boolean[string] c2t_megg_readPage(buffer page) {
	boolean[string] out;
	matcher m;
	string part;

	m = create_matcher('Extract an egg containing the dna of <select name="mid">(.*)<small>\\(\\d+/11 eggs? spawned today\\)</small>',page);
	m.find();
	part = m.group(1);
	m = create_matcher('<option value="(\\d+)"\\s*>',part);
	while (m.find())
		out[m.group(1)] = true;
	return out;
}

boolean[string] c2t_megg_readFile() {
	boolean[string] out;
	string[int] raw;

	raw = file_to_array("c2t_megg_maxlist.txt");
	foreach i,x in raw
		out[x] = true;
	return out;
}

boolean c2t_megg_writeFile(boolean[string] list) {
	buffer buf;
	boolean[int] neat;
	string prefCount = "_c2t_megg_maxlistCount";
	string prefLast = "_c2t_megg_lastCheck";
	int size = list.count();

	if (size == 0)
		return false;
	//only write if the list is actually bigger or it's a new day
	if (size <= get_property(prefCount).to_int()) {
		set_property(prefLast,now_to_int());
		return false;
	}

	//populate int map to sort by number instead of alpha-numerically, simply for neatness sake
	foreach x in list
		neat[x.to_int()] = true;
	foreach x in neat
		buf.append(`{x}\n`);
	if (buffer_to_file(buf,"c2t_megg_maxlist.txt")) {
		c2t_megg_print(`maxed egg list updated with {size} entries`);
		set_property(prefLast,now_to_int());
		set_property(prefCount,size);
		return true;
	}
	else {
		c2t_megg_print("maxed egg list couldn't be written");
		return false;
	}
}

void c2t_megg_init() {
	c2t_megg_oldFam = my_familiar();
	c2t_megg_oldEq = equipped_item($slot[familiar]);
}

