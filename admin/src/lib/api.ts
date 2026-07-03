import axios, { AxiosError, type InternalAxiosRequestConfig } from "axios";
import type { AuthTokens } from "./api-types";

const API_URL =
  process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:3000/api";

const ACCESS_KEY = "ec_admin_access";
const REFRESH_KEY = "ec_admin_refresh";

// Fired when the session can no longer be refreshed; the auth provider listens
// for it and bounces the user back to the login screen.
export const AUTH_LOGOUT_EVENT = "ec-admin-auth-logout";

export const tokenStore = {
  get access(): string | null {
    if (typeof window === "undefined") return null;
    return window.localStorage.getItem(ACCESS_KEY);
  },
  get refresh(): string | null {
    if (typeof window === "undefined") return null;
    return window.localStorage.getItem(REFRESH_KEY);
  },
  set(tokens: AuthTokens): void {
    window.localStorage.setItem(ACCESS_KEY, tokens.accessToken);
    window.localStorage.setItem(REFRESH_KEY, tokens.refreshToken);
  },
  clear(): void {
    window.localStorage.removeItem(ACCESS_KEY);
    window.localStorage.removeItem(REFRESH_KEY);
  },
};

export const api = axios.create({ baseURL: API_URL });

api.interceptors.request.use((config) => {
  const token = tokenStore.access;
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// Single-flight refresh: many concurrent 401s share one refresh request.
let refreshing: Promise<string | null> | null = null;

async function refreshAccessToken(): Promise<string | null> {
  const refreshToken = tokenStore.refresh;
  if (!refreshToken) return null;
  try {
    const res = await axios.post<AuthTokens>(`${API_URL}/auth/refresh`, {
      refreshToken,
    });
    tokenStore.set(res.data);
    return res.data.accessToken;
  } catch {
    tokenStore.clear();
    return null;
  }
}

type RetriableConfig = InternalAxiosRequestConfig & { _retry?: boolean };

api.interceptors.response.use(
  (response) => response,
  async (error: AxiosError) => {
    const original = error.config as RetriableConfig | undefined;
    const isAuthCall = original?.url?.includes("/auth/");

    if (
      error.response?.status === 401 &&
      original &&
      !original._retry &&
      !isAuthCall &&
      tokenStore.refresh
    ) {
      original._retry = true;
      if (!refreshing) {
        refreshing = refreshAccessToken().finally(() => {
          refreshing = null;
        });
      }
      const newToken = await refreshing;
      if (newToken) {
        original.headers.Authorization = `Bearer ${newToken}`;
        return api(original);
      }
      if (typeof window !== "undefined") {
        window.dispatchEvent(new Event(AUTH_LOGOUT_EVENT));
      }
    }
    return Promise.reject(error);
  },
);

export function apiErrorMessage(
  error: unknown,
  fallback = "Something went wrong",
): string {
  if (axios.isAxiosError(error)) {
    const message = error.response?.data?.message;
    if (Array.isArray(message)) return message.join(", ");
    if (typeof message === "string") return message;
  }
  return fallback;
}
