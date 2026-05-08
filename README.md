![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# MAZE

This is a maze generator. Made for the VGA competition of 2026/5/10.
The repository *technically* can implement any size. For now the default is 1x1.

- The 1x1 version will implement a fixed maze of 10x10. Random locations for start and goal.
- The 1x2 version implements 3x3 up to 10x10 fixed mazes.
- The 2x2 version does the ellier algorithm to randomize any maze from 3x3 to 10x10.

If you want another size (with more features), you can:

- Change the `info.yaml`
- Change the `src/maze.v` and define/undefine `ULTRA_SMALL_1x1` in line `78`.

## Notes

- To build manually, run

```bash
git clone https://github.com/TinyTapeout/tt-support-tools.git tt
# Creates your user config
python3 tt/tt_tool.py --create-user-config
# Hardens the GDS
python3 tt/tt_tool.py --harden --no-docker
```

- It can also be ran manually if do not like tt-support-tools (like me). Although
  you need to generate the `config_merged.json` anyways...

```bash
python3 -m librelane --run-tag wokwi --force-run-dir runs/wokwi src/config_merged.json
```

- To visualize it, just use one of the following:

```bash
python3 tt/tt_tool.py --open-in-klayout --no-docker
python3 tt/tt_tool.py --open-in-openroad --no-docker

python3 -m librelane --run-tag wokwi --force-run-dir runs/wokwi src/config_merged.json --flow OpenInKLayout
python3 -m librelane --run-tag wokwi --force-run-dir runs/wokwi src/config_merged.json --flow OpenInMagic
python3 -m librelane --run-tag wokwi --force-run-dir runs/wokwi src/config_merged.json --flow OpenInOpenROAD
```

- To run the custom docker:

```bash
docker run --net=host -it --rm -u $UID -v /etc/passwd:/etc/passwd:ro -v $HOME:$HOME -w $HOME -e DISPLAY=$DISPLAY ghcr.io/librelane/librelane:3.0.0 bash
```

- To visualaze locally:

```bash
make -C test playground
```