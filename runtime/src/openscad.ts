export interface InitOptions {
  noInitialRun?: boolean;
  print?: (text: string) => void;
  printErr?: (text: string) => void;
  locateFile?: (path: string, prefix?: string) => string;
  wasmBinary?: Uint8Array;
  onRuntimeInitialized?: () => void;
  onAbort?: (what: any) => void;
}

export interface OpenSCAD {
  callMain(args: Array<string>): number;
  FS: FS;
  locateFile?: (path: string, prefix?: string) => string;
  wasmBinary?: Uint8Array;
  onRuntimeInitialized?: () => void;
  onAbort?: (what: any) => void;
}

export interface FS {
  mkdir(path: string): void;
  rename(oldpath: string, newpath: string): void;
  rmdir(path: string): void;
  stat(path: string): unknown; //TODO: add stat result obj
  readFile(path: string): string | Uint8Array;
  readFile(path: string, opts: { encoding: "utf8" }): string;
  readFile(path: string, opts: { encoding: "binary" }): Uint8Array;
  writeFile(path: string, data: string | ArrayBufferView): void;
  unlink(path: string): void;
}

declare module globalThis {
  let OpenSCAD: Partial<OpenSCAD> | undefined;
}

let wasmModule: string;

async function OpenSCAD(options?: InitOptions): Promise<OpenSCAD> {
  if (!wasmModule) {
    const url = new URL(`./openscad.wasm.js`, import.meta.url).href;
    const request = await fetch(url);
    wasmModule = "data:text/javascript;base64," + btoa(await request.text());
  }

  const module: Partial<OpenSCAD> = {
    noInitialRun: true,
    locateFile: (path: string) => new URL(`./${path}`, import.meta.url).href,
    ...options,
  };

  const initPromise = new Promise((resolve, reject) => {
    const originalOnRuntimeInitialized = module.onRuntimeInitialized;
    module.onRuntimeInitialized = () => {
      if (originalOnRuntimeInitialized) originalOnRuntimeInitialized();
      resolve(null);
    };

    const originalOnAbort = module.onAbort;
    module.onAbort = (what: any) => {
      if (originalOnAbort) originalOnAbort(what);
      reject(new Error("Emscripten aborted: " + String(what)));
    };
  });

  globalThis.OpenSCAD = module;
  try {
    await import(wasmModule + `#${Math.random()}`);
  } catch (e) {
    throw e;
  } finally {
    delete globalThis.OpenSCAD;
  }

  await initPromise;

  return module as unknown as OpenSCAD;
}

export default OpenSCAD;
