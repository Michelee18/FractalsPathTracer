struct MateralInfo{
    albedo: vec3f,
    emissive: vec3f,
    percentSpecular: f32,
    roughness : f32,
    specularColor: vec3f,
}

struct HitInfo {
    distance: f32,
    object_id: u32,
    material: MateralInfo,
}

struct FractalParams {
    fractalType: f32,
    iterations: f32,
    foldScale: f32,
    offsetX: f32,
    offsetY: f32,
    offsetZ: f32,
    _pad1: f32,
    _pad2: f32,
}

const SUN_DIRECTION: vec3f = vec3f(0.3, 1.0, 0.5);
const SUN_COLOR: vec3f = vec3f(1.0, 0.95, 0.9);
const SUN_INTENSITY: f32 = 5.0;
const SUN_ANGULAR_SIZE: f32 = 0.9998;

const SPHERE_INTENSITY: f32 = 8.0;

fn sdBox( p : vec3f, b: vec3f ) -> f32
{
  let q : vec3f = abs(p) - b;
  return length(max(q, vec3f(0.0))) + min(max(q.x,max(q.y,q.z)),0.0);
}

// Original DE - unchanged
fn de(p_in: vec3f) -> f32 {
    var p = p_in;
    p = vec3f(fract(p.x) - 0.5, p.y, fract(p.z) - 0.5);
    var k = 1.0;
    var s = 0.0;
    
    for (var i = 0; i < 9; i++) {
        s = 2.0 / clamp(dot(p, p), 0.1, 1.0);
        p = abs(p) * s - vec3f(0.5, 3.0, 0.5);
        k *= s;
    }
    
    return length(p) / k - 0.001;
}

// Original DE1 - unchanged
fn de1(p0: vec3f) -> f32 {
    var p = fract(p0 * 0.5 + 0.5) * 2.0 - 1.0;
    p = abs(p) - 1.0;
    
    if(p.x < p.z) {
        p = p.zxy;
    }
    if(p.y < p.z) {
        p = p.xzy;
    }
    if(p.x < p.y) {
        p = p.yxz;
    }
    
    var s = 1.0;
    for(var i = 0; i < 10; i++) {
        let r2 = 2.0 / clamp(dot(p, p), 0.1, 1.0);
        p = abs(p) * r2 - vec3f(0.6, 0.6, 3.5);
        s *= r2;
    }
    
    return length(p) / s;
}

// Original DE2 - unchanged
fn de2(p0: vec3f) -> f32 {
    let itr = 10.0;
    let r = 0.1;
    var p = fract((p0 - 1.5) / 3.0) * 3.0 - 1.5;
    p = abs(p) - 1.3;
    
    if(p.x < p.z) {
        p = p.zxy;
    }
    if(p.y < p.z) {
        p = p.xzy;
    }
    if(p.x < p.y) {
        p = p.yxz;
    }
    
    var s = 1.0;
    p -= vec3f(0.5, -0.3, 1.5);
    
    for(var i = 0.0; i < itr; i += 1.0) {
        let r2 = 2.0 / clamp(dot(p, p), 0.1, 1.0);
        p = abs(p) * r2;
        p -= vec3f(0.7, 0.3, 5.5);
        s *= r2;
    }
    
    return length(p.xy) / (s - r);
}

// DE3 - NOW PARAMETERIZED
fn de3(p0: vec3f) -> f32 {
    var p = fract(p0) - 0.5;
    let O = vec3f(fractalParams.offsetX, fractalParams.offsetY, fractalParams.offsetZ);
    
    let iters = i32(fractalParams.iterations);
    for(var j = 0; j < iters; j++) {
        p = abs(p);
        p = select(p.zyx, p.zxy, p.x < p.y) * fractalParams.foldScale - O;
        if(p.z < -0.5 * O.z) {
            p.z += O.z;
        }
    }
    
    return length(p.xy) / 3e3;
}

// Original DE4 - unchanged
fn de4(p0: vec3f) -> f32 {
    var p = fract(p0) - 0.5;
    let O = vec3f(2.0, 0.0, 3.0);
    
    for(var j = 0; j < 7; j++) {
        p = abs(p);
        p = select(p.zyx, p.zxy, p.x < p.y) * 3.0 - O;
        if(p.z < -0.5 * O.z) {
            p.z += O.z;
        }
    }
    
    return length(p.xy) / 3e3;
}

fn map(pos: vec3f) -> HitInfo {
    // Select fractal based on fractalType parameter
    var fractal: f32;
    let ftype = i32(fractalParams.fractalType);
    
    if (ftype == 0) {
        fractal = de(pos);
    } else if (ftype == 1) {
        fractal = de1(pos);
    } else if (ftype == 2) {
        fractal = de2(pos);
    } else if (ftype == 3) {
        fractal = de3(pos);
    } else {
        fractal = de4(pos);
    }
    
    let lightPos: vec3f = vec3f(2.0, 0.0, 0.0);
    let lightSource: f32 = sdBox(pos - lightPos, vec3f(0.01, 0.5, 0.5));

    var result: HitInfo;
    var minDist = min(fractal, lightSource);
    var closestSphere: u32 = 0u;
    
    for (var i = 0u; i < 20u; i++) {
        let sphereDist = length(pos - spheres[i]) - 0.2;
        if (sphereDist < minDist) {
            minDist = sphereDist;
            closestSphere = i + 3u;
        }
    }
    
    if (minDist == fractal) {
        result.distance = fractal;
        result.object_id = 2u;
        result.material.albedo = vec3f(0.9, 0.9, 0.95);
        result.material.emissive = vec3f(0.0);
        result.material.percentSpecular = 0.2;
        result.material.roughness = 0.3;
        result.material.specularColor = vec3f(1.0);
    }
    else if (minDist == lightSource) {
        result.distance = lightSource;
        result.object_id = 1u;
        result.material.albedo = vec3f(0.0);
        result.material.emissive = vec3f(6.0);
        result.material.percentSpecular = 0.0;
        result.material.roughness = 0.0;
        result.material.specularColor = vec3f(0.0);
    }
    else {
        result.distance = minDist;
        result.object_id = closestSphere;
        result.material.albedo = vec3f(0.0);
        result.material.emissive = vec3f(SPHERE_INTENSITY);
        result.material.percentSpecular = 0.0;
        result.material.roughness = 0.0;
        result.material.specularColor = vec3f(0.0);
    }

    return result;
}

fn getDist(rayOrig: vec3f, rayDir: vec3f) -> HitInfo {
    var t : f32 = 0.0;
    var hit: HitInfo;

    for(var i : i32 = 0; i < 500; i++){
        let pos : vec3f = rayOrig + rayDir * t;
        let hitInfo : HitInfo = map(pos);
        t += hitInfo.distance;
        hit = hitInfo;
        if (hit.distance < 0.001 || t > 100.0) {
            break;
        }
    }
    
    hit.distance = t;
    if (t >= 100.0) {
        hit.object_id = 0u;
    }
    
    return hit;
}

fn getNormal (p: vec3f) -> vec3f {
    let d = map(p).distance;
    let e = vec2f(0.01, 0.0);
    let n = d - vec3f(
        map(p - e.xyy).distance,
        map(p - e.yxy).distance,
        map(p - e.yyx).distance,
    );
    return normalize(n);
}

fn getSkyColor(rayDir: vec3f) -> vec3f {
    let skyColor = mix(vec3f(0.5, 0.7, 1.0), vec3f(1.0), rayDir.y * 0.5 + 0.5);
    
    let sunDir = normalize(SUN_DIRECTION);
    let sunDot = dot(rayDir, sunDir);
    
    if (sunDot > SUN_ANGULAR_SIZE) {
        return SUN_COLOR * SUN_INTENSITY;
    }
    
    return skyColor * 0.5;
}

fn pathTrace (rayStartPos: vec3f, rayStartDir: vec3f) -> vec3f {
    var ret : vec3f = vec3f(0.0, 0.0, 0.0);
    var throughput : vec3f = vec3f(1.0, 1.0, 1.0);
    var rayPos : vec3f = rayStartPos;
    var rayDir : vec3f = rayStartDir;

    for (var i : u32; i < 8; i++){
        
        var hit: HitInfo = getDist(rayPos, rayDir);

        if (hit.object_id == 0u){
            ret += throughput * getSkyColor(rayDir);
            break;
        }
        
        let hitPos = rayPos + rayDir * hit.distance;
        let normal = getNormal(hitPos);

        if(length(hit.material.emissive) > 0.0){
            let emission : vec3f = hit.material.emissive;
            ret += throughput * emission;
            break;
        }

        let sunDir = normalize(SUN_DIRECTION);
        let shadowRayOrigin = hitPos + normal * 0.01;
        let shadowHit = getDist(shadowRayOrigin, sunDir);
        
        if (shadowHit.object_id == 0u) {
            let NdotL = max(dot(normal, sunDir), 0.0);
            if (NdotL > 0.0) {
                let sunContribution = hit.material.albedo * SUN_COLOR * SUN_INTENSITY * NdotL / 3.14159;
                ret += throughput * sunContribution;
            }
        }

        var specularChance: f32 = hit.material.percentSpecular;
        
        if(specularChance > 0.0){
            specularChance = FresnelReflectAmount(
                1.0, 1.0, 
                normal, rayDir, hit.material.percentSpecular, 1.0);  
        }
        
        let doSpecular : f32 = select(0.0, 1.0, RandomFloat01() < specularChance);
        let rayProbability : f32 = mix(1.0 - specularChance, specularChance, doSpecular);

        rayPos = hitPos + normal * 0.01;

        var diffuseRayDir : vec3f = normalize(normal + RandomUnitVector());
        var specularRayDir : vec3f = reflect(rayDir, normal);
        specularRayDir = normalize(mix(specularRayDir, diffuseRayDir, hit.material.roughness * hit.material.roughness));
             
        rayDir = mix(diffuseRayDir, specularRayDir, doSpecular);
        throughput *= mix(hit.material.albedo, hit.material.specularColor, doSpecular);
        throughput /= rayProbability;
        
        let p : f32 = max(throughput.r, max(throughput.g, throughput.b));
        if (RandomFloat01() > p){
            break;
        }

        throughput *= 1.0 / p;
    }

    return ret;
}

@group(0) @binding(0) var color_buffer: texture_storage_2d<rgba8unorm, write>;
@group(0) @binding(1) var<uniform> frameCount : u32;
@group(0) @binding(2) var<storage, read_write> accumulation_buffer: array<vec4f>;
@group(0) @binding(3) var<uniform> fractalParams: FractalParams;
@group(0) @binding(4) var<storage, read> spheres: array<vec3f>;

@compute @workgroup_size(8, 8, 1)
fn main(@builtin(global_invocation_id) GlobalInvocationID: vec3<u32>) {
    let screen_size: vec2<i32> = vec2<i32>(textureDimensions(color_buffer));
    let screen_pos: vec2<i32> = vec2<i32>(i32(GlobalInvocationID.x), i32(GlobalInvocationID.y));
    
    if (screen_pos.x >= screen_size.x || screen_pos.y >= screen_size.y) {
        return;
    }

    init_rng(vec2u(GlobalInvocationID.xy), frameCount);
    let jitter : vec2f = vec2f(RandomFloat01(), RandomFloat01()) - 0.5;
    var uv: vec2<f32> = (vec2<f32>(screen_pos) + jitter) / vec2<f32>(screen_size);
    uv = uv * 2.0 - 1.0;
    uv.x *= f32(screen_size.x) / f32(screen_size.y);
    uv.y *= -1.0;

    let rayOrigin : vec3f = vec3f(0.0, 0.0, -3.0);
    let rayDirection : vec3f = normalize(vec3f(uv.x, uv.y, 1.0));

    let sample_color = pathTrace(rayOrigin, rayDirection);

    let buffer_index = u32(screen_pos.y * screen_size.x + screen_pos.x);

    var accumulated : vec3f;
    if(frameCount == 1u) {
        accumulated = sample_color;
    } else {
        let prev = accumulation_buffer[buffer_index].rgb;
        accumulated = prev + (sample_color - prev) / f32(frameCount);
    }

    accumulation_buffer[buffer_index] = vec4f(accumulated, 1.0);
    
    accumulated *= 0.5;
    accumulated = ACESFilm(accumulated);
    let display_color = LinearToSRGB(accumulated);
    textureStore(color_buffer, screen_pos, vec4f(display_color, 1.0));
}

fn LessThan(f : vec3f, value: f32) -> vec3f
{
    return vec3(
        select(0.0f, 1.0f, f.x < value),
        select(0.0f, 1.0f, f.y < value),
        select(0.0f, 1.0f, f.z < value)
    );
}
 
fn LinearToSRGB(rgb : vec3f) -> vec3f
{
    let clamped = clamp(rgb, vec3f(0.0f), vec3f(1.0f));
 
    return mix(
        pow(clamped, vec3(1.0f / 2.4f)) * 1.055f - 0.055f,
        clamped * 12.92f,
        LessThan(clamped, 0.0031308f)
    );
}
 
fn SRGBToLinear(rgb: vec3f) -> vec3f
{
    let clamped = clamp(rgb, vec3f(0.0f), vec3f(1.0f));
 
    return mix(
        pow(((clamped + 0.055f) / 1.055f), vec3(2.4f)),
        clamped / 12.92f,
        LessThan(clamped, 0.04045f)
    );
}

fn ACESFilm(x : vec3f) -> vec3f
{
    let a : f32 = 2.51f;
    let b : f32 = 0.03f;
    let c : f32 = 2.43f;
    let d : f32 = 0.59f;
    let e : f32 = 0.14f;
    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), vec3f(0.0f), vec3f(1.0f));
}

var<private> rng_state: u32;

fn init_rng(pixel: vec2u, frame: u32) {
    var seed = pixel.x + pixel.y * 1920u + frame * 719393u;
    seed = seed * 747796405u + 2891336453u;
    seed = ((seed >> ((seed >> 28u) + 4u)) ^ seed) * 277803737u;
    seed = (seed >> 22u) ^ seed;
    rng_state = seed;
}

fn RandomFloat01() -> f32 {
    rng_state = rng_state ^ (rng_state << 13u);
    rng_state = rng_state ^ (rng_state >> 17u);
    rng_state = rng_state ^ (rng_state << 5u);
    return f32(rng_state) / 4294967296.0;
}

fn RandomUnitVector() -> vec3f {
    let z: f32 = RandomFloat01() * 2.0 - 1.0;
    let a: f32 = RandomFloat01() * 6.283;
    let r: f32 = sqrt(1.0 - z * z);
    let x: f32 = r * cos(a);
    let y: f32 = r * sin(a);
    return vec3(x, y, z);
}

fn FresnelReflectAmount(n1: f32, n2: f32, normal: vec3f, incident: vec3f, f0: f32, f90: f32) -> f32
{
    var r0 = (n1 - n2) / (n1 + n2);
    r0 *= r0;
    var cosX = -dot(normal, incident);
    
    if (n1 > n2)
    {
        let n = n1 / n2;
        let sinT2 = n * n * (1.0 - cosX * cosX);
        if (sinT2 > 1.0)
        {
            return f90;
        }
        cosX = sqrt(1.0 - sinT2);
    }
    
    let x = 1.0 - cosX;
    let ret = r0 + (1.0 - r0) * x * x * x * x * x;
    
    return mix(f0, f90, ret);
}