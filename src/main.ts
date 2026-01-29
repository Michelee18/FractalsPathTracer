import { Renderer } from "./renderer";

const canvas : HTMLCanvasElement = <HTMLCanvasElement> document.getElementById("gfx-main");
const renderer = new Renderer(canvas);

renderer.initialize();

// Setup slider event listeners
const sliders = [
    { id: 'iterations', param: 'iterations' as const, decimals: 0 },
    { id: 'fold-scale', param: 'foldScale' as const, decimals: 1 },
    { id: 'offset-x', param: 'offsetX' as const, decimals: 1 },
    { id: 'offset-y', param: 'offsetY' as const, decimals: 1 },
    { id: 'offset-z', param: 'offsetZ' as const, decimals: 1 }
];

sliders.forEach(config => {
    const slider = document.getElementById(config.id) as HTMLInputElement;
    const valueDisplay = document.getElementById(`${config.id}-value`);
    
    if (slider && valueDisplay) {
        slider.addEventListener('input', (e) => {
            const value = parseFloat((e.target as HTMLInputElement).value);
            valueDisplay.textContent = value.toFixed(config.decimals);
            renderer.updateFractalParam(config.param, value);
        });
    }
});

// Fractal selector
const fractalSelect = document.getElementById('fractal-select') as HTMLSelectElement;
const fractalDisplay = document.getElementById('fractal-display');

if (fractalSelect && fractalDisplay) {
    fractalSelect.addEventListener('change', (e) => {
        const value = parseInt((e.target as HTMLSelectElement).value);
        const names = ['DE', 'DE1', 'DE2', 'DE3', 'DE4'];
        fractalDisplay.textContent = names[value];
        renderer.updateFractalParam('fractalType', value);
    });
}

// Refresh lights button
const refreshButton = document.getElementById('refresh-lights');
if (refreshButton) {
    refreshButton.addEventListener('click', () => {
        renderer.refreshLightPositions();
    });
}

// FPS Counter
let lastTime = performance.now();
let frames = 0;
let lastFpsUpdate = performance.now();

function updateFPS() {
    const now = performance.now();
    frames++;
    
    if (now - lastFpsUpdate >= 500) {
        const fps = Math.round((frames * 1000) / (now - lastFpsUpdate));
        const frameTime = ((now - lastFpsUpdate) / frames).toFixed(1);
        
        const fpsDisplay = document.getElementById('fps-display');
        const frametimeDisplay = document.getElementById('frametime-display');
        const samplesDisplay = document.getElementById('samples-display');
        
        if (fpsDisplay) fpsDisplay.textContent = fps.toString();
        if (frametimeDisplay) frametimeDisplay.textContent = frameTime + 'ms';
        if (samplesDisplay) samplesDisplay.textContent = renderer.frameCount.toString();
        
        frames = 0;
        lastFpsUpdate = now;
    }
    
    lastTime = now;
    requestAnimationFrame(updateFPS);
}

updateFPS();