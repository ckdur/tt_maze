// An index.ts for

import tt_um_maze_v from './tt_um_maze.v?raw';
import hsync_generator_v from './hsync_generator.v?raw';
import gamepad_pmod_v from './gamepad_pmod.v?raw';
import maze_v from './maze.v?raw';
import prbs_generator_v from './prbs_generator.v?raw';
import single_port_sync_ram_v from './single_port_sync_ram.v?raw';

export const maze = {
  id: 'maze',
  name: 'Maze',
  author: 'Ckristian Duran',
  sources: {
    'tt_um_maze.v': tt_um_maze_v,
    'hsync_generator.v': hsync_generator_v,
    'gamepad_pmod.v': gamepad_pmod_v,
    'maze.v': maze_v,
    'prbs_generator.v': prbs_generator_v,
    'single_port_sync_ram.v': single_port_sync_ram_v,
  },
};
