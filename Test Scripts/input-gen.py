import itertools

# Define the options
primary_options = {
    "-v": "",
    "-r": "1",
    "-t": "10",
    "-p": "127.0.0.1:443",
    "-T": "www.facebook.com"
}

secondary_options = {
    "-ua": "\"Mozilla/5.0 (Macintosh; U; i386 Mac OS X; en) AppleWebKit/417.9 (KHTML, like Gecko) Hana/1.0sdfjsdfjsahdfjsad\"",
    "-B": "Hana",
    "-P": "Mobile",
    "-s": "\"ua-3918\",\"ua-3917\",\"ua-3916\""
}

single_options = ["-h", "-l"]

# Generate combinations
combinations = set()

# Single options are added as is
for opt in single_options:
    combinations.add(f"python3 proxy_bypass.py {opt}")

# Primary combinations
for r in range(1, len(primary_options) + 1):
    for subset in itertools.combinations(primary_options, r):
        cmd = "python3 proxy_bypass.py " + " ".join([f"{k} {primary_options[k]}" for k in subset])
        combinations.add(cmd)
        # Add with secondary options
        for secondary_key, secondary_value in secondary_options.items():
            combinations.add(cmd + f" {secondary_key} {secondary_value}")

# Write to file
with open("proxy_bypass_combinations_updated_v2.txt", "w") as f:
    for comb in combinations:
        f.write(comb + "\n")

print("Combinations written to file.")
