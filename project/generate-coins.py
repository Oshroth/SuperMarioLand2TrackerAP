coinMapping = [
    (88, "@Mushroom Zone/Coinsanity/Coins"),
    (118, "@Tree Zone 1/Coinsanity/Coins"),
	(98, "@Tree Zone 2/Coinsanity/Coins"),
	(75, "@Tree Zone Secret Course/Coinsanity/Coins"),
	(74, "@Tree Zone 4/Coinsanity/Coins"),
	(25, "@Tree Zone 3/Coinsanity/Coins"),
	(33, "@Tree Zone 5/Coinsanity/Coins"),
	(4, "@Scenic Course/Coinsanity/Coins"),
	(171, "@Hippo Zone/Coinsanity/Coins"),
	(131, "@Space Zone 1/Coinsanity/Coins"),
	(100, "@Space Zone Secret Course/Coinsanity/Coins"),
	(132, "@Space Zone 2/Coinsanity/Coins"),
	(77, "@Turtle Zone 1/Coinsanity/Coins"),
	(27, "@Turtle Zone 2/Coinsanity/Coins"),
	(97, "@Turtle Zone Secret Course/Coinsanity/Coins"),
	(59, "@Turtle Zone 3/Coinsanity/Coins"),
	(114, "@Mario Zone 1/Coinsanity/Coins"),
	(46, "@Mario Zone 2/Coinsanity/Coins"),
	(57, "@Mario Zone 3/Coinsanity/Coins"),
	(63, "@Mario Zone 4/Coinsanity/Coins"),
	(40, "@Pumpkin Zone 1/Coinsanity/Coins"),
	(36, "@Pumpkin Zone 2/Coinsanity/Coins"),
	(61, "@Pumpkin Zone 3/Coinsanity/Coins"),
	(409, "@Pumpkin Zone Secret Course 1/Coinsanity/Coins"),
	(12, "@Pumpkin Zone Secret Course 2/Coinsanity/Coins"),
	(73, "@Pumpkin Zone 4/Coinsanity/Coins"),
	(97, "@Macro Zone 1/Coinsanity/Coins"),
	(69, "@Macro Zone 2/Coinsanity/Coins"),
	(115, "@Macro Zone 3/Coinsanity/Coins"),
	(61, "@Macro Zone 4/Coinsanity/Coins"),
	(35, "@Macro Zone Secret Course/Coinsanity/Coins"),
    (0, "End")
] 
firstCoin = 61
coinIndex = 0
coinCount = firstCoin
for i in range(len(coinMapping)):
    tempCoin = coinMapping[i][0]
    coinMapping[i] = (coinCount, coinMapping[i][1])
    coinCount += tempCoin
lines = ["COIN_MAPPING = {\n"]
for i in range(firstCoin, coinCount):
    if i >= coinMapping[coinIndex + 1][0]:
        coinIndex += 1
    coin = coinMapping[coinIndex]
    lines.append(f"\t[{i}] = {{\"{coin[1]}\", {i - coin[0] + 1}}},\n")
lines.append("}\n\n")
coinMapping.pop()
lines.append("COIN_MAPPING_LOCATIONS = {\n")
for location in coinMapping:
    lines.append(f"\t{{\"{location[1]}\", \"{location[1].replace("Coinsanity/Coins", "Coinsanity/Available Coins")}\"}},\n")
lines.append("}")

with open("coin_mapping.lua", "w", encoding="utf-8") as f:
    f.writelines(lines)