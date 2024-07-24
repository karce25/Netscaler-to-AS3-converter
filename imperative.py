import re

# The path to your text file
file_path = 'bigip.txt'

# Read the contents of the file
with open(file_path, 'r') as file:
    file_contents = file.read()

# Define the regex pattern and replacement string for pools
pattern_pool = r"(ltm pool /Common/).+/(.+)"
replacement_pool = r"\1\2"

# Define the regex pattern and replacement string for pools inside VS
pattern_pool_2 = r"(pool /Common/).+/(.+)"
replacement_pool_2 = r"\1\2"

# Define the regex pattern and replacement string for virtual servers
pattern_virtual = r"(ltm virtual /Common/).+/(.+)"
replacement_virtual = r"\1\2"


# Define the regex pattern and replacement string for tcp profiles
pattern_profiles = r"(ltm profile tcp /Common/).+/(.+)"
replacement_profiles= r"\1\2"

# Define the regex pattern and replacement string for tcp profiles
pattern_profiles_cssl = r"(ltm profile client-ssl /Common/).+/(.+)"
replacement_profiles_cssl= r"\1\2"

# Define the regex pattern and replacement string for tcp profiles inside VS
pattern_profiles_2 = r"(        /Common/).+/(.+)"
replacement_profiles_2= r"\1\2"

# Regex pattern to insert "#" on all the passphrase lines
#pattern_pass= r"^\s*(passphrase)"
#replacement_pass= r"# \1"


# Replace all occurrences in the file contents for pools
updated_contents = re.sub(pattern_pool, replacement_pool, file_contents, flags=re.MULTILINE)

# Replace all occurrences in the file contents for pools inside VS
updated_contents = re.sub(pattern_pool_2, replacement_pool_2, file_contents, flags=re.MULTILINE)

# Replace all occurrences in the file contents for virtual servers
updated_contents = re.sub(pattern_virtual, replacement_virtual, updated_contents, flags=re.MULTILINE)

# Replace all occurrences in the file contents for TCP profiles
updated_contents = re.sub(pattern_profiles, replacement_profiles, updated_contents, flags=re.MULTILINE)


# Replace all occurrences in the file contents for TCP profiles
updated_contents = re.sub(pattern_profiles_cssl, replacement_profiles_cssl, updated_contents, flags=re.MULTILINE)

# Replace all occurrences in the file contents for TCP profiles inside VS
updated_contents = re.sub(pattern_profiles_2, replacement_profiles_2, updated_contents, flags=re.MULTILINE)

# Replace all occurrences in the file contents for TCP profiles inside VS
#updated_contents = re.sub(pattern_pass, replacement_pass, updated_contents, flags=re.MULTILINE)


# Write the updated contents back to the file
with open(file_path, 'w') as file:
    file.write(updated_contents)

print(f"The file {file_path} has been updated.")