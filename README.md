### OUTDATED (updating soon)

# Archinstall
This is a personal automated Arch Installation script, changes may added.

## Notice!
This script aims for modularity so you'll have to do the networking, partitioning and mounting steps yourself.

## Usage:

If you want to change some part of the script.

Grab the script with:

```
curl https://raw.githubusercontent.com/DanteAKD/Archinstall/main/arch-install.sh -o arch-install.sh
```
Review it with your editor of choice, example nano:

```
nano arch-install.sh
```

Then make it executable:

```
chmod +x arch-install.sh
```

Finally exec it:

```
./arch-install.sh
```

If you've reviewed the script and see the options suit to your use case, run it directly:

```
curl -fsSL https://raw.githubusercontent.com/DanteAKD/Archinstall/main/arch-install.sh | bash
```

## Post installation:

You must clone the repository:

```
git clone https://github.com/DanteAKD/Archinstall.git
```

Make the post installation script executable:

```
cd Archinstall
sudo chmod +x post-install.sh
```

Run the script:

```
sudo ./post-install.sh
```
