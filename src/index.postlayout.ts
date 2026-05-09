// An index.ts for

import tt_um_maze_v from './tt_um_maze.nl.v?raw';
import primitives_v from './primitives.v?raw';
import sky130_fd_sc_hd_v from './sky130_fd_sc_hd.v?raw';

export const maze = {
  id: 'maze',
  name: 'Maze',
  author: 'Ckristian Duran',
  sources: {
    'tt_um_maze.nl.v': tt_um_maze_v,
    'primitives.v': primitives_v,
    'sky130_fd_sc_hd.v': sky130_fd_sc_hd_v
  },
};
