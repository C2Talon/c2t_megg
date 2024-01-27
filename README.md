# c2t_megg

Kolmafia script written in ASH to add various interfaces for mimic eggs from the chest mimic. It will maintain a list of eggs that are already maximally donated in order to not waste effort. It does this through updating a data file any time any of the functions sees the list of eggs that can be extracted, or if the user manually visits the page through the relay browser.

## Installation

Can be installed via the KoLmafia CLI:
* `git checkout https://github.com/C2Talon/c2t_megg.git master`

## Usage

### Functions

When `import`ed, the following functions can be used:

`boolean c2t_megg_donate(monster)`
* used to donate as many eggs of `monster` to the Mimic DNA Bank as it can
* will not donate eggs that it knows are already maximally donated
* `monster` can be omitted to donate random eggs
* returns `false` only on some critical failure

`boolean c2t_megg_extract(monster)`
* used to extract a mimic egg containing `monster` from the Mimic DNA Bank
* returns `true` on success, `false` on failure

`boolean c2t_megg_fight(monster)`
* enter a fight against `monster` from a mimic egg
* will not automate or run the fight for you
* returns `true` if left in combat from the mimic egg, `false` if not

`boolean c2t_megg_preAdv()`
* put this in a pre-adventure script to maintain the data file that helps to not donate eggs that are already maximally donated
* will run only when the chest mimic has enough experience to be able to see the data
* by default, it will only try to update the data file 30 minutes after the last successful update this function did; this limitation can be changed by changing the `c2t_megg_timeLimit` preference using minutes
* returns `true` only if the max egg data file is updated

`boolean c2t_megg_update()`
* tries to update the max egg list if able, without the time restrictions of the pre-adventure function
* returns `true` only if the max egg data file is updated

### CLI

All of the above functions can also be accessed via the CLI. The list of commands and a short description of what each does will be displayed with the following:
* `c2t_megg help`

### Relay override script

When visiting the Mimic DNA Bank in the relay browser, the maxed egg list will be updated automatically if able. The script will also clean up the the names of monsters by removing the articles at the beginning, as well as making the drop-down menus searchable as can be seen here:

[relay_cleaner_example.png](https://github.com/C2Talon/c2t_megg/blob/master/relay_cleaner_example.png "relay cleaner example")

The cleaning behavior of the relay script can be enabled or disabled via the CLI:

`c2t_megg cleaner <on|off>`

