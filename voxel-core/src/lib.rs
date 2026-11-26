use wasm_bindgen::prelude::*;

const GRID_SIZE: usize = 32;
const TOTAL_VOXELS: usize = GRID_SIZE * GRID_SIZE * GRID_SIZE;

// Voxel materials: 0 = Air, 1 = Wood (Cottage/Boat), 2 = Stone, 3 = Brick/Roof, 4 = Foliage
#[wasm_bindgen]
pub struct VoxelWorld {
    voxels: Vec<u8>,
    // Instance buffer: x, y, z, mat_id (f32 * 4 per active voxel)
    instance_buffer: Vec<f32>,
    active_count: usize,
}

#[wasm_bindgen]
impl VoxelWorld {
    #[wasm_bindgen(constructor)]
    pub fn new() -> VoxelWorld {
        let mut world = VoxelWorld {
            voxels: vec![0; TOTAL_VOXELS],
            instance_buffer: Vec::with_capacity(TOTAL_VOXELS * 4),
            active_count: 0,
        };
        world.generate_sample_scene();
        world.rebuild_instances();
        world
    }

    fn index(x: usize, y: usize, z: usize) -> usize {
        x + y * GRID_SIZE + z * GRID_SIZE * GRID_SIZE
    }

    pub fn generate_sample_scene(&mut self) {
        self.voxels.fill(0);
        // Build dock/pier and a coastal cottage
        // Base dock
        for x in 4..16 {
            for z in 4..10 {
                self.set_voxel(x, 2, z, 1);
            }
        }
        // Cottage walls
        for x in 16..26 {
            for z in 8..18 {
                for y in 2..8 {
                    if x == 16 || x == 25 || z == 8 || z == 17 {
                        self.set_voxel(x, y, z, 2);
                    }
                }
            }
        }
        // Door cutout
        self.set_voxel(16, 2, 12, 0);
        self.set_voxel(16, 3, 12, 0);

        // Roof
        for y in 8..13 {
            let offset = y - 8;
            for x in (15 + offset)..(27 - offset) {
                for z in (7 + offset)..(19 - offset) {
                    self.set_voxel(x, y, z, 3);
                }
            }
        }

        // Boat floating nearby
        for x in 6..12 {
            for z in 14..18 {
                self.set_voxel(x, 1, z, 1);
                if x == 6 || x == 11 || z == 14 || z == 17 {
                    self.set_voxel(x, 2, z, 1);
                }
            }
        }
    }

    pub fn set_voxel(&mut self, x: usize, y: usize, z: usize, mat: u8) {
        if x < GRID_SIZE && y < GRID_SIZE && z < GRID_SIZE {
            let idx = Self::index(x, y, z);
            self.voxels[idx] = mat;
        }
    }

    pub fn explode(&mut self, cx: f32, cy: f32, cz: f32, radius: f32) -> usize {
        let r2 = radius * radius;
        let mut destroyed = 0;
        for z in 0..GRID_SIZE {
            for y in 0..GRID_SIZE {
                for x in 0..GRID_SIZE {
                    let dx = x as f32 - cx;
                    let dy = y as f32 - cy;
                    let dz = z as f32 - cz;
                    if dx * dx + dy * dy + dz * dz <= r2 {
                        let idx = Self::index(x, y, z);
                        if self.voxels[idx] != 0 {
                            self.voxels[idx] = 0;
                            destroyed += 1;
                        }
                    }
                }
            }
        }
        if destroyed > 0 {
            self.rebuild_instances();
        }
        destroyed
    }

    pub fn rebuild_instances(&mut self) {
        self.instance_buffer.clear();
        let mut count = 0;
        for z in 0..GRID_SIZE {
            for y in 0..GRID_SIZE {
                for x in 0..GRID_SIZE {
                    let idx = Self::index(x, y, z);
                    let mat = self.voxels[idx];
                    if mat != 0 {
                        // Check if voxel is exposed (has at least one air neighbor) for culling
                        let exposed = x == 0 || x == GRID_SIZE - 1
                            || y == 0 || y == GRID_SIZE - 1
                            || z == 0 || z == GRID_SIZE - 1
                            || self.voxels[Self::index(x - 1, y, z)] == 0
                            || self.voxels[Self::index(x + 1, y, z)] == 0
                            || self.voxels[Self::index(x, y - 1, z)] == 0
                            || self.voxels[Self::index(x, y + 1, z)] == 0
                            || self.voxels[Self::index(x, y, z - 1)] == 0
                            || self.voxels[Self::index(x, y, z + 1)] == 0;

                        if exposed {
                            self.instance_buffer.push(x as f32);
                            self.instance_buffer.push(y as f32);
                            self.instance_buffer.push(z as f32);
                            self.instance_buffer.push(mat as f32);
                            count += 1;
                        }
                    }
                }
            }
        }
        self.active_count = count;
    }

    pub fn get_instance_ptr(&self) -> *const f32 {
        self.instance_buffer.as_ptr()
    }

    pub fn get_instance_count(&self) -> usize {
        self.active_count
    }

    pub fn get_instance_data(&self) -> js_sys::Float32Array {
        unsafe {
            js_sys::Float32Array::view(&self.instance_buffer)
        }
    }
}
