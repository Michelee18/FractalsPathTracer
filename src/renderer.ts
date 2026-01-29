import { clear } from "console";
import shader from "./shaders.wgsl";
import raytracer_kernel from "./rayMarching.wgsl"
import screen_shader from "./shaders.wgsl"
import { TriangleMesh } from "./triangleMesh";
import { Triangle } from "./triMesh";
import { CubeMapMaterial } from "./cubemap";

export class Renderer {

    canvas : HTMLCanvasElement
    adapter : GPUAdapter
    device : GPUDevice 
    context : GPUCanvasContext 
    format : GPUTextureFormat 

    rayMarchingPipeline : GPUComputePipeline
    rayMarchingbindGroup: GPUBindGroup

    screenPipeline : GPURenderPipeline
    screenBindGroup: GPUBindGroup

    //assets
    colorBuffer: GPUTexture
    colorBufferView: GPUTextureView

    sphereBuffer: GPUBuffer

    accumulationBuffer: GPUBuffer

    timeBuffer: GPUBuffer
    frameCount: number = 0
    sampler: GPUSampler
    triangleMesh: Triangle

    transformBuffer : GPUBuffer

    // Fractal parameters (sliders only affect DE3)
    fractalParams = {
        fractalType: 3,    // Which fractal to render (0-4)
        iterations: 7,
        foldScale: 3.0,
        offsetX: 2.0,
        offsetY: 0.0,
        offsetZ: 5.0,
        _pad1: 0,
        _pad2: 0
    };

    constructor(canvas: HTMLCanvasElement){
        this.canvas = canvas;
    }

    // Public method to update fractal parameters from outside
    updateFractalParam(param: keyof typeof this.fractalParams, value: number) {
        this.fractalParams[param] = value;
        this.resetAccumulation();
    }

    // Public method to refresh light sphere positions
    refreshLightPositions() {
        const staticStorageValues = new Float32Array(20 * 3);

        for (let i = 0; i < 20; ++i) {
            staticStorageValues.set([
                -2.0 + 4.0 * Math.random(),
                -2.0 + 4.0 * Math.random(),
                -5.0 + 8.0 * Math.random()
            ], i * 3);
        }
        this.device.queue.writeBuffer(this.sphereBuffer, 0, staticStorageValues);
        this.resetAccumulation();
    }

    resetAccumulation() {
        this.frameCount = 0;
        const zeros = new Float32Array(this.canvas.width * this.canvas.height * 4);
        this.device.queue.writeBuffer(this.accumulationBuffer, 0, zeros);
    }

    async initialize(){
        await this.setupDevice();
        await this.createAssets();
        await this.makePipeline();
        this.render();
    }

    async setupDevice() {
        this.adapter = <GPUAdapter> await navigator.gpu?.requestAdapter();
        this.device = <GPUDevice> await this.adapter?.requestDevice();
        this.context = <GPUCanvasContext> this.canvas.getContext("webgpu");
        this.format = "bgra8unorm";
        this.context.configure({
            device: this.device,
            format: this.format,
            alphaMode: "opaque"
        });
    }

    async createAssets(){

        this.timeBuffer = this.device.createBuffer({
            size: 4,
            usage : GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
        });

        this.colorBuffer = this.device.createTexture(
            {
                size: {
                    width: this.canvas.width,
                    height: this.canvas.height,
                },
                format: "rgba8unorm",
                usage: GPUTextureUsage.COPY_DST | GPUTextureUsage.STORAGE_BINDING | GPUTextureUsage.TEXTURE_BINDING
            }
        );

        this.colorBufferView = this.colorBuffer.createView();

        const bufferSize = this.canvas.width * this.canvas.height * 4 * 4;
        this.accumulationBuffer = this.device.createBuffer({
            size: bufferSize,
            usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST
        });

        this.transformBuffer = this.device.createBuffer({
            size: 8*4, // 8 floats
            usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
        })

        const samplerDescriptor: GPUSamplerDescriptor = {
            addressModeU: "repeat",
            addressModeV: "repeat",
            magFilter: "linear",
            minFilter: "nearest",
            mipmapFilter: "nearest",
            maxAnisotropy: 1
        };
        this.sampler = this.device.createSampler(samplerDescriptor);

        this.sphereBuffer = this.device.createBuffer({
            size: 20*3*4,
            usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST,
        })

        const staticStorageValues = new Float32Array(20 * 3);

        for (let i = 0; i < 20; ++i) {
            staticStorageValues.set([
                -2.0 + 4.0 * Math.random(),
                -2.0 + 4.0 * Math.random(),
                -5.0 + 8.0 * Math.random()
            ], i * 3);
        }
        this.device.queue.writeBuffer(this.sphereBuffer, 0, staticStorageValues);
    }

    async makePipeline(){

        const rayMarchingBindGroupLayout = this.device.createBindGroupLayout({
            entries: [
               { binding: 0,
                visibility: GPUShaderStage.COMPUTE,
                storageTexture: {
                    access: "write-only",
                    format: "rgba8unorm",
                    viewDimension: "2d"
                } 
                },
                {
                    binding: 1,
                    visibility: GPUShaderStage.COMPUTE,
                    buffer: {
                        type: "uniform"
                    }
                },
                 { 
                    binding: 2,
                    visibility: GPUShaderStage.COMPUTE,
                    buffer: {
                    type: "storage"
            }
            },

            { 
                    binding: 3,
                    visibility: GPUShaderStage.COMPUTE,
                    buffer: {
                    type: "uniform"
            }
            },
            { 
                    binding: 4,
                    visibility: GPUShaderStage.COMPUTE,
                    buffer: {
                    type: "read-only-storage"
            }
            }
            ]
        });

        this.rayMarchingbindGroup = this.device.createBindGroup({
            layout: rayMarchingBindGroupLayout,
            entries: [
                {
                    binding: 0,
                    resource: this.colorBufferView,
                },
                {
                    binding: 1,
                    resource: {
                        buffer: this.timeBuffer,
                    }
                },
                {
                    binding: 2,
                    resource: {
                        buffer: this.accumulationBuffer,
                    }
                    
                },
                {
                    binding: 3,
                    resource: {
                        buffer: this.transformBuffer,
                    }
                    
                },
                {
                    binding: 4,
                    resource: {
                        buffer: this.sphereBuffer,
                    }
                    
                }

            ]
        });

        const rayMarchingPipelineLayout = this.device.createPipelineLayout({
            bindGroupLayouts: [rayMarchingBindGroupLayout]
        });
    
        this.rayMarchingPipeline = this.device.createComputePipeline({
            layout: rayMarchingPipelineLayout,
            compute: {
                module: this.device.createShaderModule({
                code: raytracer_kernel,
            }),
            entryPoint: 'main',
            },
        });

        const screenBindGroupLayout = this.device.createBindGroupLayout({
            entries: [
                {
                    binding: 0,
                    visibility: GPUShaderStage.FRAGMENT,
                    sampler: {}
                },
                {
                    binding: 1,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: {}
                },
            ]
        });

        this.screenBindGroup = this.device.createBindGroup({
            layout: screenBindGroupLayout,
            entries: 
            [
                 {
                    binding: 0,
                    resource:  this.sampler
                },
                {
                    binding: 1,
                    resource: this.colorBufferView
                }
            ]
        });

        const screenPipelineLayout = this.device.createPipelineLayout({
            bindGroupLayouts: [screenBindGroupLayout]
        });

        this.screenPipeline = this.device.createRenderPipeline({

            layout: screenPipelineLayout,

            vertex: {

                module : this.device.createShaderModule({
                    code : screen_shader
                }),
                entryPoint : "vs_main",

            },
    
            fragment : {
                module : this.device.createShaderModule({
                    code : screen_shader
                }),
                entryPoint : "fs_main",
                targets : [{
                    format : this.format
                }]
            },
    
            primitive : {
                topology : "triangle-list"
            }
    
        });

    }

    render = () => {

        this.frameCount ++;

        // Write fractal parameters to transform buffer
        const fractalData = new Float32Array([
            this.fractalParams.fractalType,
            this.fractalParams.iterations,
            this.fractalParams.foldScale,
            this.fractalParams.offsetX,
            this.fractalParams.offsetY,
            this.fractalParams.offsetZ,
            this.fractalParams._pad1,
            this.fractalParams._pad2
        ]);

        this.device.queue.writeBuffer(this.transformBuffer, 0, fractalData);

        const commandEncoder : GPUCommandEncoder = this.device.createCommandEncoder();
        const rayMarchPass: GPUComputePassEncoder = commandEncoder.beginComputePass();

        this.device.queue.writeBuffer(
            this.timeBuffer,
            0,
            new Uint32Array([this.frameCount])
        )
        rayMarchPass.setPipeline(this.rayMarchingPipeline);
        rayMarchPass.setBindGroup(0, this.rayMarchingbindGroup);
        rayMarchPass.dispatchWorkgroups(
            Math.ceil(this.canvas.width/8),
            Math.ceil(this.canvas.height/8), 1
        );
        rayMarchPass.end();

        const textureView : GPUTextureView = this.context.getCurrentTexture().createView();
        const renderpass : GPURenderPassEncoder = commandEncoder.beginRenderPass({
            colorAttachments: [{
                view: textureView,
                clearValue: {r: 0.5, g: 0.0, b: 0.25, a: 1.0},
                loadOp: "clear",
                storeOp: "store"
            }]
        });
        renderpass.setPipeline(this.screenPipeline);
        renderpass.setBindGroup(0, this.screenBindGroup);
        renderpass.draw(6, 1, 0, 0);
        renderpass.end();
    
        this.device.queue.submit([commandEncoder.finish()]);

        requestAnimationFrame(this.render);

    }
}