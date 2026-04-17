import {
  type FC,
  type PropsWithChildren,
  useCallback,
  useContext,
  useEffect,
} from 'react';

import { ErrorContext } from '../errorHandling/ErrorContext';
import { ErrorTypes } from '../errorHandling/utils';
import { useAuth } from 'react-oidc-context';
import { AuthContext } from './AuthContext';

const AuthContextProvider: FC<PropsWithChildren> = props => {
  const { children } = props;
  
  // Check if we're in local development mode
  const isLocalDevMode = import.meta.env.VITE_APP_LOCAL_DEV_MODE === 'true';
  const localDevUserId = import.meta.env.VITE_APP_LOCAL_DEV_USER_ID || 's343424';
  
  const {
    isAuthenticated,
    isLoading,
    user,
    signinRedirect,
    removeUser,
    signoutRedirect,
    startSilentRenew,
  } = useAuth();

  const { makeErrorCatcher, setExecLogin, execLogin } =
    useContext(ErrorContext);

  const loginErrorCatcher = makeErrorCatcher(ErrorTypes.AuthError);

  useEffect(() => {
    if (isAuthenticated && !isLocalDevMode) {
      startSilentRenew();
    }
  }, [startSilentRenew, isAuthenticated, isLocalDevMode]);

  useEffect(() => {
    if (!isLocalDevMode && !isLoading && (!isAuthenticated || execLogin)) {
      signinRedirect().catch(loginErrorCatcher);
      setExecLogin(false);
    }
  }, [
    execLogin,
    setExecLogin,
    isLoading,
    isAuthenticated,
    signinRedirect,
    loginErrorCatcher,
    isLocalDevMode,
  ]);

  const logout = useCallback(() => {
    if (isLocalDevMode) {
      return Promise.resolve();
    }
    return removeUser()
      .then(() => signoutRedirect())
      .catch(loginErrorCatcher);
  }, [removeUser, signoutRedirect, loginErrorCatcher, isLocalDevMode]);

  // In local dev mode, provide mock authentication
  if (isLocalDevMode) {
    return (
      <AuthContext.Provider
        value={{
          isLoggedIn: true,
          token: undefined, // No token in local dev mode
          userId: localDevUserId,
          profile: {
            preferred_username: localDevUserId,
            name: 'Local Dev User',
            email: 'local@dev.local',
            sub: localDevUserId,
            iss: 'local-dev',
            aud: 'crownlabs',
            exp: 0,
            iat: 0,
            groups: ['kubernetes:admin'], // Grant admin access in local dev mode
          },
          logout,
        }}
      >
        {children}
      </AuthContext.Provider>
    );
  }

  return isLoading ? null : (
    <AuthContext.Provider
      value={{
        isLoggedIn: isAuthenticated,
        token: user?.id_token,
        userId: user?.profile.preferred_username || '',
        profile: user?.profile,
        logout,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
};

export default AuthContextProvider;
