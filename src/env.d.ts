/// <reference types="vite/client" />

declare global {
  interface ImportMetaEnv {
    readonly VITE_MODE?: string;
  }
}

export {};
