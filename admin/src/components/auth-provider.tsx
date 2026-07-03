"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useState,
} from "react";
import { api, apiErrorMessage, AUTH_LOGOUT_EVENT, tokenStore } from "@/lib/api";
import type { AuthResult, PublicUser } from "@/lib/api-types";

type AuthStatus = "loading" | "authed" | "guest";

interface AuthContextValue {
  user: PublicUser | null;
  status: AuthStatus;
  login: (email: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
}

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<PublicUser | null>(null);
  const [status, setStatus] = useState<AuthStatus>("loading");

  const clearSession = useCallback(() => {
    tokenStore.clear();
    setUser(null);
    setStatus("guest");
  }, []);

  // Restore the session on first load: if we hold a token, ask the API who we
  // are. A failed /me (e.g. expired + unrefreshable) drops us to guest.
  useEffect(() => {
    let active = true;
    if (!tokenStore.access) {
      setStatus("guest");
      return;
    }
    api
      .get<PublicUser>("/auth/me")
      .then((res) => {
        if (!active) return;
        setUser(res.data);
        setStatus("authed");
      })
      .catch(() => {
        if (!active) return;
        clearSession();
      });
    return () => {
      active = false;
    };
  }, [clearSession]);

  // The axios interceptor emits this when a refresh fails mid-session.
  useEffect(() => {
    const onLogout = () => clearSession();
    window.addEventListener(AUTH_LOGOUT_EVENT, onLogout);
    return () => window.removeEventListener(AUTH_LOGOUT_EVENT, onLogout);
  }, [clearSession]);

  const login = useCallback(async (email: string, password: string) => {
    let result: AuthResult;
    try {
      const res = await api.post<AuthResult>("/auth/login", {
        email,
        password,
      });
      result = res.data;
    } catch (error) {
      throw new Error(apiErrorMessage(error, "Invalid email or password"));
    }
    // This panel is admin-only; reject non-admin accounts before storing tokens.
    if (result.user.role !== "ADMIN") {
      throw new Error("This account is not an administrator.");
    }
    tokenStore.set(result);
    setUser(result.user);
    setStatus("authed");
  }, []);

  const logout = useCallback(async () => {
    const refreshToken = tokenStore.refresh;
    if (refreshToken) {
      // Best-effort server-side revocation; local state is cleared regardless.
      await api.post("/auth/logout", { refreshToken }).catch(() => undefined);
    }
    clearSession();
  }, [clearSession]);

  return (
    <AuthContext.Provider value={{ user, status, login, logout }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext);
  if (!ctx) {
    throw new Error("useAuth must be used within an AuthProvider");
  }
  return ctx;
}
