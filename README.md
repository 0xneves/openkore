## ROLA Openkore

This is a simpler version of the original readme that only contains what I'm personally using to debug my development on this repo.

## Setup

Just hit next on everything and install.

- [ ] [GNU Make - Complete package, except sources](https://gnuwin32.sourceforge.net/packages/make.htm)
- [ ] [Perl - 5.40.2.1 MSI](https://strawberryperl.com/)
- [ ] [Python - 3.14](https://www.python.org/downloads/)

## Running

Open a terminal and navigate to the root of the openkore folder and type:

```bash
$ gmake
``` 

Navigate to `openkore/src/Poseidon` and type:

```bash
$ perl poseidon.pl
``` 

Leave that terminal open, go to a new one and navigate to openkore root folder again. Then type:

```bash
$ perl openkore.pl
``` 

## Commands

```bash
# Monster Safety & Combat
$ hei avoid          # See what monsters are avoided on current map  
$ hei hunt           # Manual monster hunting (with safety filtering)

# Stats & Progression  
$ hei stats          # Quick stat summary
$ hei status         # Detailed stat distribution status
$ hei distribute     # Manual stat distribution

# Resources
$ hei inv            # Inventory summary

# Help
$ hei help           # Show all commands
```