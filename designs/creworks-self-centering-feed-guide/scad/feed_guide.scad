// CREWORKS Self-Centering Feed Guide
// Parametric OpenSCAD — measure your machine first (see ../MEASURE.md)
//
// Units: millimeters
// Print: PETG or ABS, 0.2 mm layer, 4+ walls, 40% gyroid, no supports for most parts
//
// Usage:
//   1. Set MEASURED PARAMETERS below
//   2. Set part = "assembly" | "plate" | "jaw_left" | "jaw_right" | "pinion" | "cover" | "all_flat"
//   3. F6 render → Export STL

/* [Measured parameters] */
screw_spacing   = 140;   // A — thumbscrew hole C-C (mm)
screw_clearance = 8.5;   // B — clearance hole diameter
centerline_z    = 55;    // C — roller V depth height from plate bottom
plate_w         = 170;   // D — mount plate width
plate_h         = 100;   // D — mount plate height
max_wire_d      = 38;    // E — largest wire diameter to guide

/* [Design parameters] */
plate_t         = 8;     // mount plate thickness
jaw_t           = 12;    // jaw thickness (feed direction depth)
jaw_face_angle  = 90;    // included V angle (degrees)
min_wire_d      = 1.5;   // smallest wire — jaws nearly closed
spring_hook_d   = 3.2;   // hole for spring hook / M3
pinion_teeth    = 12;
rack_module     = 1.5;   // gear module (mm) — coarse for FDM
pinion_bore     = 5.2;   // M5 shoulder bolt / pin clearance
slot_clearance  = 0.35;  // sliding fit on FDM
flare_len       = 18;    // lead-in flare length in front of jaws
flare_open      = 55;    // mouth opening at entrance (mm)
show_wire_d     = 12;    // preview wire diameter in assembly
part            = "assembly"; // assembly | plate | jaw_left | jaw_right | pinion | cover | all_flat

/* [Hidden] */
$fn = 64;
eps = 0.02;
jaw_travel = max_wire_d / 2 + 2;
v_half = jaw_face_angle / 2;
rack_face_h = 14;
jaw_body_h = plate_h - 16;
jaw_body_w = (plate_w - screw_spacing) / 2 + screw_spacing / 2 - 8;

// ---------------------------------------------------------------------------
// Helpers
module rounded_rect(w, h, t, r=3) {
    linear_extrude(t)
        offset(r=r) offset(r=-r)
            square([w, h], center=true);
}

module screw_holes() {
    for (x = [-screw_spacing/2, screw_spacing/2])
        translate([x, 0, -eps])
            cylinder(h=plate_t + 2*eps, d=screw_clearance);
}

// ---------------------------------------------------------------------------
// Mount plate — replaces OEM 5-hole plate
module mount_plate() {
    difference() {
        // body, origin at plate center in XY, Z up from back face
        translate([0, 0, 0])
            rounded_rect(plate_w, plate_h, plate_t, 4);

        // thumbscrew holes — plate Y=0 is geometric center;
        // shift so centerline_z from bottom matches roller
        translate([0, centerline_z - plate_h/2, 0])
            screw_holes();

        // central window for jaws + wire
        window_w = max_wire_d + 2*jaw_travel + 10;
        window_h = max(max_wire_d + 16, 50);
        translate([0, centerline_z - plate_h/2, -eps])
            rounded_rect(window_w, window_h, plate_t + 2*eps, 2);

        // horizontal T-slot / rail pockets for jaws (simplified rectangular rails)
        rail_w = jaw_travel + jaw_body_w * 0.55;
        rail_h = 10;
        for (side = [-1, 1])
            translate([side * (window_w/2 + rail_w/2 - 2), centerline_z - plate_h/2, plate_t/2])
                cube([rail_w, rail_h + slot_clearance, plate_t + eps], center=true);

        // pinion axle bore (through plate)
        translate([0, centerline_z - plate_h/2, -eps])
            cylinder(h=plate_t + 2*eps, d=pinion_bore);

        // spring anchor holes (outer)
        for (side = [-1, 1])
            translate([side * (screw_spacing/2 - 12), centerline_z - plate_h/2, -eps])
                cylinder(h=plate_t + 2*eps, d=spring_hook_d);
    }

    // raised rail guides (print as part of plate — top surface)
    window_w = max_wire_d + 2*jaw_travel + 10;
    for (side = [-1, 1])
        translate([side * (window_w/4), centerline_z - plate_h/2 - 22, plate_t])
            cube([window_w/2 - 4, 4, 3], center=true);
}

// ---------------------------------------------------------------------------
// V-jaw (left = -1, right = +1)
// Local XY: apex of the V sits on x=0; body extends outward along +x (right) or -x (left).
module jaw(side=1) {
    body_w = 32;
    body_h = max_wire_d + 24;
    // 90° V: half-angle 45°, depth sized for max_wire/2 plus margin
    v_depth = max_wire_d / 2 + 6;
    v_half_w = v_depth; // tan(45°)=1

    difference() {
        // Outer blank, shifted so the V apex is at x=0
        translate([side * body_w / 2, 0, jaw_t / 2])
            cube([body_w, body_h, jaw_t], center=true);

        // Triangular V notch: apex on the centerline edge (x=0),
        // cutting into the jaw body (toward +x for right, -x for left).
        translate([0, 0, -eps])
            linear_extrude(jaw_t + 2 * eps)
                polygon(points = [
                    [-side * eps, 0],
                    [side * v_depth,  v_half_w],
                    [side * v_depth, -v_half_w]
                ]);

        // Spring hook hole (outer upper corner)
        translate([side * (body_w - 7), body_h / 2 - 7, -eps])
            cylinder(h=jaw_t + 2 * eps, d=spring_hook_d);

        // Underside rail slot
        translate([side * body_w / 2, -body_h / 2 + 6, 1.4])
            cube([body_w - 8, 4.2 + slot_clearance, 3.2], center=true);
    }

    // Rack teeth facing the pinion (toward centerline)
    tooth_pitch = PI * rack_module;
    n_teeth = max(6, floor((body_h - 10) / tooth_pitch));
    for (i = [0:n_teeth - 1]) {
        ty = -body_h / 2 + 6 + i * tooth_pitch;
        translate([side * 1.2, ty, jaw_t / 2])
            cube([2.8, tooth_pitch * 0.42, jaw_t - 1], center=true);
    }
}

// ---------------------------------------------------------------------------
// Pinion — meshes both racks
module pinion() {
    pitch_d = pinion_teeth * rack_module;
    outer_d = pitch_d + 2 * rack_module;
    difference() {
        union() {
            cylinder(h=jaw_t - 1, d=outer_d);
            // hub
            translate([0, 0, jaw_t - 1])
                cylinder(h=plate_t + 2, d=pinion_bore + 4);
        }
        translate([0, 0, -eps])
            cylinder(h=jaw_t + plate_t + 4, d=pinion_bore);
        // crude tooth gaps
        tooth_a = 360 / pinion_teeth;
        for (i = [0:pinion_teeth-1])
            rotate([0, 0, i * tooth_a])
                translate([pitch_d/2 + rack_module * 0.2, 0, jaw_t/2 - 0.5])
                    cube([rack_module * 1.6, rack_module * 0.9, jaw_t], center=true);
    }
}

// ---------------------------------------------------------------------------
// Front flare / cover — funnels wire into jaws, keeps chips out
module cover_flare() {
    difference() {
        hull() {
            translate([0, 0, 0])
                rounded_rect(flare_open + 20, flare_open + 16, 2, 3);
            translate([0, 0, flare_len])
                rounded_rect(max_wire_d + 24, max_wire_d + 20, 2, 3);
        }
        hull() {
            translate([0, 0, -eps])
                cylinder(h=2, d=flare_open);
            translate([0, 0, flare_len + eps])
                cylinder(h=2, d=max_wire_d + 6);
        }
        // screw pass-throughs aligned to plate
        for (x = [-screw_spacing/2, screw_spacing/2])
            translate([x, centerline_z - plate_h/2, -eps])
                cylinder(h=flare_len + 10, d=screw_clearance + 0.5);
    }
}

// ---------------------------------------------------------------------------
// Assembly preview
module assembly_preview() {
    color("SteelBlue")
        mount_plate();

    gap = show_wire_d / 2;
    color("LightGray")
        translate([-gap - 2, centerline_z - plate_h/2, plate_t + 1])
            rotate([0, 0, 0])
                jaw(-1);
    color("Gainsboro")
        translate([gap + 2, centerline_z - plate_h/2, plate_t + 1])
            jaw(1);

    color("Goldenrod")
        translate([0, centerline_z - plate_h/2, plate_t + 1])
            pinion();

    color("DimGray", 0.35)
        translate([0, centerline_z - plate_h/2, plate_t + jaw_t + 2])
            cover_flare();

    // preview wire
    color("Copper", 0.8)
        translate([0, centerline_z - plate_h/2, plate_t + jaw_t/2])
            rotate([0, 90, 0])
                cylinder(h=80, d=show_wire_d, center=true);
}

module all_flat() {
    // laid out for single-plate print / DXF export mindset
    translate([0, 0, 0]) mount_plate();
    translate([0, -plate_h/2 - 50, 0]) jaw(-1);
    translate([60, -plate_h/2 - 50, 0]) jaw(1);
    translate([-60, -plate_h/2 - 50, 0]) pinion();
    translate([0, plate_h/2 + 60, 0]) cover_flare();
}

// ---------------------------------------------------------------------------
if (part == "plate")      mount_plate();
else if (part == "jaw_left")  jaw(-1);
else if (part == "jaw_right") jaw(1);
else if (part == "pinion") pinion();
else if (part == "cover")  cover_flare();
else if (part == "all_flat") all_flat();
else assembly_preview();
