use wasm_bindgen::prelude::*;

const MAX_PARTICLES: usize = 3000;

#[derive(Clone, Copy)]
pub struct Particle {
    pub x: f32,
    pub y: f32,
    pub z: f32,
    pub vx: f32,
    pub vy: f32,
    pub vz: f32,
    pub life: f32,
    pub max_life: f32,
    pub size: f32,
    pub r: u8,
    pub g: u8,
    pub b: u8,
    pub a: u8,
    pub mode: u8, // 1: Sparks, 2: Explosion, 3: Fire, 4: Smoke, 5: Water, 6: Magic
}

#[wasm_bindgen]
pub struct VfxWorld {
    width: usize,
    height: usize,
    particles: Vec<Particle>,
    framebuffer: Vec<u8>,
    depth_buffer: Vec<f32>,
    cam_x: f32,
    cam_y: f32,
    cam_z: f32,
    cam_yaw: f32,
    cam_pitch: f32,
    time: f32,
    rng_state: u32,
}

#[wasm_bindgen]
impl VfxWorld {
    #[wasm_bindgen(constructor)]
    pub fn new(width: usize, height: usize) -> VfxWorld {
        let size = width * height;
        let mut world = VfxWorld {
            width,
            height,
            particles: Vec::with_capacity(MAX_PARTICLES),
            framebuffer: vec![0; size * 4],
            depth_buffer: vec![1000.0; size],
            cam_x: 0.0,
            cam_y: 8.0,
            cam_z: -16.0,
            cam_yaw: 0.0,
            cam_pitch: -0.32,
            time: 0.0,
            rng_state: 1234567,
        };
        world.trigger_burst(1, 400);
        world
    }

    fn next_rand(&mut self) -> f32 {
        self.rng_state = self.rng_state.wrapping_mul(1664525).wrapping_add(1013904223);
        (self.rng_state >> 16) as f32 / 65535.0
    }

    pub fn set_camera(&mut self, x: f32, y: f32, z: f32, yaw: f32, pitch: f32) {
        self.cam_x = x;
        self.cam_y = y;
        self.cam_z = z;
        self.cam_yaw = yaw;
        self.cam_pitch = pitch;
    }

    pub fn trigger_burst(&mut self, mode: u8, count: usize) {
        for _ in 0..count {
            let px = (self.next_rand() - 0.5) * 3.0;
            let py = 1.0 + self.next_rand() * 1.0;
            let pz = (self.next_rand() - 0.5) * 3.0;

            let (vx, vy, vz, life, size, r, g, b) = match mode {
                1 => {
                    // Sparks (SPARK engine restitution bounce)
                    let angle = self.next_rand() * std::f32::consts::TAU;
                    let speed = 8.0 + self.next_rand() * 14.0;
                    (angle.cos() * speed, 5.0 + self.next_rand() * 10.0, angle.sin() * speed, 1.0 + self.next_rand() * 1.5, 0.18, 255, 210, 40)
                }
                2 => {
                    // Explosion
                    let angle = self.next_rand() * std::f32::consts::TAU;
                    let speed = 12.0 + self.next_rand() * 16.0;
                    (angle.cos() * speed, 4.0 + self.next_rand() * 14.0, angle.sin() * speed, 0.8 + self.next_rand() * 1.2, 0.45, 255, 70, 15)
                }
                3 => {
                    // Fire
                    ((self.next_rand() - 0.5) * 2.0, 3.0 + self.next_rand() * 5.0, (self.next_rand() - 0.5) * 2.0, 0.6 + self.next_rand() * 0.8, 0.35, 255, 120, 20)
                }
                4 => {
                    // Smoke
                    ((self.next_rand() - 0.5) * 1.5, 1.5 + self.next_rand() * 3.0, (self.next_rand() - 0.5) * 1.5, 2.0 + self.next_rand() * 1.5, 0.55, 130, 140, 155)
                }
                5 => {
                    // Water
                    let angle = self.next_rand() * std::f32::consts::TAU;
                    let speed = 4.0 + self.next_rand() * 6.0;
                    (angle.cos() * speed, 4.0 + self.next_rand() * 5.0, angle.sin() * speed, 1.2 + self.next_rand() * 1.0, 0.22, 30, 180, 255)
                }
                _ => {
                    // Magic
                    let angle = self.next_rand() * std::f32::consts::TAU;
                    (angle.cos() * 5.0, 2.0 + self.next_rand() * 6.0, angle.sin() * 5.0, 1.4 + self.next_rand() * 1.0, 0.3, 230, 30, 255)
                }
            };

            let p = Particle {
                x: px, y: py, z: pz,
                vx, vy, vz,
                life, max_life: life,
                size, r, g, b, a: 255, mode,
            };

            if self.particles.len() < MAX_PARTICLES {
                self.particles.push(p);
            } else {
                let idx = (self.rng_state as usize) % MAX_PARTICLES;
                self.particles[idx] = p;
            }
        }
    }

    pub fn update_and_render(&mut self, dt: f32) {
        self.time += dt;

        let w = self.width;
        let h = self.height;

        // Clear Framebuffer to dark gradient
        for y in 0..h {
            let row_factor = y as f32 / h as f32;
            let bg_r = (10.0 + row_factor * 12.0) as u8;
            let bg_g = (14.0 + row_factor * 16.0) as u8;
            let bg_b = (24.0 + row_factor * 26.0) as u8;

            for x in 0..w {
                let idx = (y * w + x) * 4;
                self.framebuffer[idx] = bg_r;
                self.framebuffer[idx + 1] = bg_g;
                self.framebuffer[idx + 2] = bg_b;
                self.framebuffer[idx + 3] = 255;
            }
        }
        self.depth_buffer.fill(1000.0);

        // Render Voxel Grid Platform (Y = 0)
        self.render_floor();

        // Update & Render Particles
        let cam_cos_yaw = self.cam_yaw.cos();
        let cam_sin_yaw = self.cam_yaw.sin();
        let cam_cos_pitch = self.cam_pitch.cos();
        let cam_sin_pitch = self.cam_pitch.sin();

        for i in 0..self.particles.len() {
            let mut p = self.particles[i];
            if p.life <= 0.0 {
                continue;
            }

            p.life -= dt;

            // Physics per mode
            if p.mode == 3 {
                p.vy += 5.0 * dt;
                p.vx += (self.time * 6.0 + p.y).sin() * 0.4 * dt;
            } else if p.mode == 4 {
                p.vy += 1.8 * dt;
                p.size += 0.12 * dt;
            } else {
                p.vy -= 9.81 * dt;
            }

            p.vx *= 0.99;
            p.vz *= 0.99;

            p.x += p.vx * dt;
            p.y += p.vy * dt;
            p.z += p.vz * dt;

            // Platform collision (Y = 0)
            if p.y <= 0.0 {
                p.y = 0.0;
                if p.mode == 1 || p.mode == 2 {
                    p.vy = -p.vy * 0.65; // Bounce
                    p.vx *= 0.85;
                    p.vz *= 0.85;
                } else if p.mode == 5 {
                    p.vy = -p.vy * 0.1;
                    p.vx *= 1.05;
                    p.vz *= 1.05;
                } else {
                    p.vy = 0.0;
                }
            }

            self.particles[i] = p;

            // Project 3D to 2D Screen
            let rel_x = p.x - self.cam_x;
            let rel_y = p.y - self.cam_y;
            let rel_z = p.z - self.cam_z;

            let x1 = rel_x * cam_cos_yaw - rel_z * cam_sin_yaw;
            let z1 = rel_x * cam_sin_yaw + rel_z * cam_cos_yaw;

            let y2 = rel_y * cam_cos_pitch - z1 * cam_sin_pitch;
            let z2 = rel_y * cam_sin_pitch + z1 * cam_cos_pitch;

            if z2 > 0.5 {
                let fov_scale = (h as f32) * 0.85;
                let sx = ((x1 / z2) * fov_scale + (w as f32) * 0.5) as isize;
                let sy = ((-y2 / z2) * fov_scale + (h as f32) * 0.5) as isize;
                let p_radius = ((p.size / z2) * fov_scale).max(1.0) as isize;

                let norm_life = (p.life / p.max_life).clamp(0.0, 1.0);
                let alpha_r = ((p.r as f32) * norm_life) as u8;
                let alpha_g = ((p.g as f32) * norm_life) as u8;
                let alpha_b = ((p.b as f32) * norm_life) as u8;

                for dy in -p_radius..=p_radius {
                    for dx in -p_radius..=p_radius {
                        let px = sx + dx;
                        let py = sy + dy;
                        if px >= 0 && px < w as isize && py >= 0 && py < h as isize {
                            let pidx = py as usize * w + px as usize;
                            if z2 < self.depth_buffer[pidx] {
                                self.depth_buffer[pidx] = z2;
                                let fidx = pidx * 4;
                                self.framebuffer[fidx] = self.framebuffer[fidx].saturating_add(alpha_r);
                                self.framebuffer[fidx + 1] = self.framebuffer[fidx + 1].saturating_add(alpha_g);
                                self.framebuffer[fidx + 2] = self.framebuffer[fidx + 2].saturating_add(alpha_b);
                            }
                        }
                    }
                }
            }
        }
    }

    fn render_floor(&mut self) {
        let w = self.width;
        let h = self.height;

        let cam_cos_yaw = self.cam_yaw.cos();
        let cam_sin_yaw = self.cam_yaw.sin();
        let cam_cos_pitch = self.cam_pitch.cos();
        let cam_sin_pitch = self.cam_pitch.sin();

        // Draw perspective grid floor at Y = 0
        for gx in (-16..=16).step_by(2) {
            for gz in (-16..=16).step_by(2) {
                let fx = gx as f32;
                let fz = gz as f32;

                let rel_x = fx - self.cam_x;
                let rel_y = 0.0 - self.cam_y;
                let rel_z = fz - self.cam_z;

                let x1 = rel_x * cam_cos_yaw - rel_z * cam_sin_yaw;
                let z1 = rel_x * cam_sin_yaw + rel_z * cam_cos_yaw;

                let y2 = rel_y * cam_cos_pitch - z1 * cam_sin_pitch;
                let z2 = rel_y * cam_sin_pitch + z1 * cam_cos_pitch;

                if z2 > 0.5 {
                    let fov_scale = (h as f32) * 0.85;
                    let sx = ((x1 / z2) * fov_scale + (w as f32) * 0.5) as isize;
                    let sy = ((-y2 / z2) * fov_scale + (h as f32) * 0.5) as isize;

                    if sx >= 0 && sx < w as isize && sy >= 0 && sy < h as isize {
                        let pidx = sy as usize * w + sx as usize;
                        if z2 < self.depth_buffer[pidx] {
                            self.depth_buffer[pidx] = z2;
                            let fidx = pidx * 4;
                            self.framebuffer[fidx] = 45;
                            self.framebuffer[fidx + 1] = 65;
                            self.framebuffer[fidx + 2] = 85;
                        }
                    }
                }
            }
        }
    }

    pub fn get_framebuffer_ptr(&self) -> *const u8 {
        self.framebuffer.as_ptr()
    }

    pub fn get_particle_count(&self) -> usize {
        self.particles.len()
    }
}
