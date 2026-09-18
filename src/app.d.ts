import type { API } from '../shared/contracts';
declare global {
  interface Window {
    helm: API;
  }
}
export {};
