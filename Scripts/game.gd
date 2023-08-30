extends Control

# PRELOAD UI OBJECTS
const PlayerInput = preload("res://Scenes/player_input.tscn")
const GPTResponse = preload("res://Scenes/gpt_response.tscn")
const InventoryItem = preload("res://Scenes/inventory_item.tscn")

# INSTATIATE VARIABLES FOR UI OBJECTS
@onready var inventory_rows = $Background/Margins/Columns/VBoxContainer/Inventory/InventoryRows
@onready var history_rows = $Background/Margins/Columns/Rows/GameInfo/MarginContainer/ScrollContainer/ChatHistory
@onready var scroll = $Background/Margins/Columns/Rows/GameInfo/MarginContainer/ScrollContainer
@onready var scroll_bar = scroll.get_v_scroll_bar()
@onready var health_bar = $Background/Margins/Columns/VBoxContainer/HealthBar
@onready var music_player = $MusicPlayer

# PLAYER STATS
var inventory = []
var player_health = 100
var player_gold = 100

# CONVERSATION VARIABLES
var conversation = []
var current_dialogue_response
var current_dialogue_call = "I want you to take on the role similar to a dungeon master for a simple adventure game called ChatRPG.
You are only to respond in JSON format.
Do not respond to this message directly, just begin the game by saying 'Welcome to ChatRPG!' and asking for the setting and my character name and backstory."
var current_dialogue_bio = "You are a dungeon master. Describe everything in beautiful, decorative language, and gently lead the player toward interesting things. 
Make me roll a d20 if I'm trying to do somthing I could reasonably fail at."
var token_cutoff = 2000
var current_song = null


func _ready():
	scroll_bar.changed.connect(_on_scroll_changed)
	get_dialogue(current_dialogue_call)

# HANDLE TEXT SUBMITTED
func _on_input_text_submitted(new_text):
	# Set the dialogue and send dialogue request
	current_dialogue_call = new_text
	get_dialogue(current_dialogue_call)
	
	# Add the player input to the history window
	var player_input = PlayerInput.instantiate()
	player_input.set_text(current_dialogue_call)
	history_rows.add_child(player_input)
	

# SEND A DIALOGUE REQUEST AND CONNECT TO COMPLETE REQUEST
func get_dialogue(input):
	const URL = 'https://api.openai.com/v1/chat/completions'
	var headers = ["Content-Type: application/json","Authorization: Bearer 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"]
	
	# Format string for the response
	var format_response = '
	Non Combat instructions:
	Describe the surroundings to the player. Include things like enviornment, people, and interesting things when relevant. At the end, gently lead the player toward the next moment in the story. Give the player some direction, but make it subtle.
	
	Combat instructions:
	Combat begins when the player attacks or is attacked. The player and enemy(s) should take turns attacking, and each turn should be a single response from you. The player should be prompted to roll each turn, either to determine the success of the player attack or the success of the player defence.
	
	Response instructions:
	Determine if this is a combat situation or a non combat situation.
	
	Check if this action, statement, question, or number in the "player_response" field of the JSON is a valid action. If the player tries to use an item it must exist in the "inventory" field of the JSON, otherwise the action is invalid.
	
	{"player_response" : "%s", "inventory" : %s, "health" : %s}.
	
	Now respond to me with JSON. The JSON should have the following structure:
		{
		"response" : CHATGPT RESPONSE GOES HERE,
		"item_gained" : [ANY ITEM THE PLAYER HAS OBTAINED IN THIS TURN],
		"item_lost" : [ANY ITEM THE PLAYER LOST IN THIS TURN],
		"health_gained" : HEALTH GAINED IN THIS TURN, SHOULD BE AN INTEGER,
		"health_lost" : HEALTH LOST IN THIS TURN, SHOULD BE AN INTEGER,
		"music" : CHOOSE "battle", "magical", or "plesant"
	}'
	var response = format_response % [input, get_inventory_string(inventory), player_health]
	
	# Prompt template
	var prompt = {
	"model": "gpt-4",
	"temperature": 1,
	"messages": conversation + [
	{"role": "system", "content": current_dialogue_bio},
	{"role": "user", "content": response}
		] 
	}
	
	var json = JSON.stringify(prompt)
	
	# Create new http request
	var request = HTTPRequest.new()
	add_child(request)
	
	# Connect to request completion function
	request.request_completed.connect(_on_request_completed)
	
	# Send request
	request.request(URL, headers, HTTPClient.METHOD_POST, json)
	print('request sent')



# HANDLE REQUEST COMPLETION
func _on_request_completed(_result, _response_code, _headers, body):
	print('request completed')
	
	# Parse the JSON string of the response
	var response = JSON.parse_string(body.get_string_from_utf8())
	
	# If the response was completed properly, set the current dialogue
	if response:
		current_dialogue_response = response['choices'][0]['message']['content']
		print(response['usage']['total_tokens'])
		if response['usage']['total_tokens'] >= token_cutoff:
			get_recap()
	else:
		current_dialogue_response = "Connection failed. Check internet connection and try again."
	
	# Parse the JSON string of the current response
	var json_response = JSON.parse_string(current_dialogue_response)
	
	if not verify_json(json_response):
		get_dialogue(current_dialogue_call)
		return
	
	# Instantiate a response UI object and set the text
	var gpt_response = GPTResponse.instantiate()
	gpt_response.set_text(json_response['response'])
	history_rows.add_child(gpt_response)
	
	# Handle inventory checks
	item_to_inventory(json_response['item_gained'])
	item_from_inventory(json_response['item_lost'])
	
	# Handle health checks
	health_check(json_response['health_gained'], json_response['health_lost'])
	
	# Add the response to the ongoing conversation
	conversation.append({"role": "user", "content": current_dialogue_call})
	conversation.append({"role": 'system', "content": current_dialogue_response})
	
	print(conversation)
	
	
# SEND A RECAP REQUEST AND CONNECT TO COMPLETE REQUEST
func get_recap():
	const URL = 'https://api.openai.com/v1/chat/completions'
	var headers = ["Content-Type: application/json","Authorization: Bearer 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"]
	
	var response = 'Please provide a brief and concise recap of the story so far. Specifically include in detail the last scene'
	
	# Prompt template
	var prompt = {
	"model": "gpt-4",
	"temperature": 1,
	"messages": conversation + [
	{"role": "system", "content": 'Respond in plain text, not JSON'},
	{"role": "user", "content": response}
		] 
	}
	
	var json = JSON.stringify(prompt)
	
	# Create new http request
	var request = HTTPRequest.new()
	add_child(request)
	
	# Connect to request completion function
	request.request_completed.connect(_on_recap_request_completed)
	
	# Send request
	request.request(URL, headers, HTTPClient.METHOD_POST, json)
	print('recap request sent')


# HANDLE RECAP COMPLETION
func _on_recap_request_completed(_result, _response_code, _headers, body):
	print('recap request completed')
	
	# Parse the JSON string of the response
	var response = JSON.parse_string(body.get_string_from_utf8())
	
	# If the response was completed properly, set the current dialogue
	if response:
		print(response['usage']['total_tokens'])
		current_dialogue_response = response['choices'][0]['message']['content']
	else:
		current_dialogue_response = "Connection failed. Check internet connection and try again."
		
	# Add the response to the ongoing conversation
	conversation = [conversation[-1], conversation[-2]]
	conversation.append({"role": "user", "content": current_dialogue_call})
	conversation.append({"role": 'system', "content": current_dialogue_response})


# PUSH SCROLL BAR TO THE BOTTOM WHEN NEW TEXT IS ADDED
func _on_scroll_changed():
	scroll.scroll_vertical = scroll_bar.max_value


# ADD AN ITEM TO THE INVENTORY
func item_to_inventory(item_array):
		for item in range(0, item_array.size()):
		
			var inventory_item = InventoryItem.instantiate()
			inventory_item.set_the_text(item_array[item])
		
			inventory_rows.add_child(inventory_item)
			
			inventory.append(item_array[item])
			

# REMOVE AN ITEM FROM THE INVENTORY
func item_from_inventory(item_array):
	var inv = inventory_rows.get_children()
	for item in inv:
		for lost_item in item_array:
			if lost_item == item.text:
				item.queue_free()


# ADD OR REMOVE PLAYER HEALTH
func health_check(healing, damage):
	if healing != 0:
		player_health += healing
	if damage != 0:
		player_health -= damage
	
	health_bar.value = player_health	


# GET THE INVENTORY STRING TO BE SENT WITH PLAYER RESPONSE	
func get_inventory_string(inventory):
	var inventory_string = ''
	for i in range(0,inventory.size()):
		inventory_string += '"' + inventory[i] + '"'
		
	return '[' + inventory_string + ']'


# VERIFY THE STRUCTURE OF THE JSON RESPONSE
func verify_json(dict):
	if typeof(dict) != 27:
		return false
	if not dict.has('response'):
		return false
	if not dict.has('item_gained'):
		return false
	if not dict.has('item_lost'):
		return false
	if not dict.has('health_gained'):
		return false
	if not dict.has('health_lost'):
		return false
	return true

